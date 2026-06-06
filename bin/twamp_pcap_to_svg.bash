#!/bin/bash

PCAP_FILE="$1"
PCAP_BASE=$(basename --suffix=.pcap "$PCAP_FILE")

OUT_DIR="${2:-$(pwd)}"

tshark -d 'udp.port==0-65000,twamp.test' -r "$PCAP_FILE" -T fields \
    -e frame.number -tr -e frame.time_relative -e _ws.col.Source \
    -e _ws.col.Destination -e udp.dstport -e twamp.test.sender_seq_number \
    -e twamp.test.seq_number -E separator=, -E header=y \
    > "$OUT_DIR/$PCAP_BASE.csv"

docker run --rm -it \
    -v "$OUT_DIR":/workspace \
    -w /workspace \
    alpine rm "$PCAP_BASE.db"

docker run --rm -it \
    -v "$OUT_DIR":/workspace \
    -w /workspace \
    alpine/sqlite -batch -cmd ".import \"/workspace/$PCAP_BASE.csv\" csv --csv"  "$PCAP_BASE.db" ".quit"


cat << EOF > "$OUT_DIR/$PCAP_BASE.mp"
filenametemplate "%j-%c.svg";
outputformat := "svg";
outputformatoptions := "format=rgb antialias=best";
hppp := 0.1;
vppp := 0.1;
tracingonline:=1;
u := 1cm;

pair sender_seqs[];
pair reflector_seqs[];
pair received_places[];
pair receiveds[];
numeric reflector_seq_offset[];
numeric received_offset[];

EOF


docker run --rm -it \
    -v "$OUT_DIR":/workspace \
    -w /workspace \
    alpine/sqlite --list -batch -cmd \
    "\
    select concat('min_sender_seq := ', min(cast(\"twamp.test.sender_seq_number\" as decimal)), ';') from csv;\
    select concat('max_sender_seq := ', max(cast(\"twamp.test.sender_seq_number\" as decimal)), ';') from csv; \
    select concat('min_reflector_seq := ', min(cast(\"twamp.test.seq_number\" as decimal)), ';') from csv;\
    select concat('max_reflector_seq := ', max(cast(\"twamp.test.seq_number\" as decimal)), ';') from csv;\
    select concat('nb_receiveds :=', count(*), ';') from csv;\
    " \
    "$PCAP_BASE.db" ".quit" >> "$OUT_DIR/$PCAP_BASE.mp"


cat << EOF >> "$OUT_DIR/$PCAP_BASE.mp"

% for absent iseq_reflectors
for iseq_reflector = min_reflector_seq upto max_reflector_seq:
    reflector_seq_offset[iseq_reflector] := min_sender_seq - min_reflector_seq + iseq_reflector;
endfor;

EOF


docker run --rm -it \
    -v "$OUT_DIR":/workspace \
    -w /workspace \
    alpine/sqlite --list -batch -cmd \
    "\
    select concat('reflector_seq_offset[', \"twamp.test.seq_number\", '] := ', min(cast(\"twamp.test.sender_seq_number\" as DECIMAL)), ';')
    from csv
    group by \"twamp.test.seq_number\"
    order by cast(\"twamp.test.seq_number\" as DECIMAL)
    limit 1;

    select concat('reflector_seq_offset[',
        \"twamp.test.seq_number\", 
        '] := max(', 
        min(cast(\"twamp.test.sender_seq_number\" as DECIMAL)), 
        ', reflector_seq_offset[', 
        cast(\"twamp.test.seq_number\" as DECIMAL) - 1,
        '] + 1);')
    from csv
    group by \"twamp.test.seq_number\"
    order by cast(\"twamp.test.seq_number\" as DECIMAL)
    limit 100000 offset 1;
    " \
    "$PCAP_BASE.db" ".quit" >> "$OUT_DIR/$PCAP_BASE.mp"


cat << EOF >> "$OUT_DIR/$PCAP_BASE.mp"

% for absent iseq_reflectors
for iseq_reflector = min_reflector_seq + 1 upto max_reflector_seq:
    reflector_seq_offset[iseq_reflector] := max(reflector_seq_offset[iseq_reflector], reflector_seq_offset[iseq_reflector - 1] + 1);
endfor;

EOF


docker run --rm -it \
    -v "$OUT_DIR":/workspace \
    -w /workspace \
    alpine/sqlite --list -batch -cmd \
    "\
    select concat('receiveds[', CAST(\"frame.number\" as DECIMAL) - 1, '] := (',\"twamp.test.sender_seq_number\", ',' , \"twamp.test.seq_number\", ');') from csv; \
    " \
    "$PCAP_BASE.db" ".quit" >> "$OUT_DIR/$PCAP_BASE.mp"


cat << EOF >> "$OUT_DIR/$PCAP_BASE.mp"

beginfig(1);
for iseq_sender = min_sender_seq upto max_sender_seq:
   sender_seqs[iseq_sender] := (u, -u * iseq_sender);
   label.lft(decimal(iseq_sender), sender_seqs[iseq_sender]);
endfor;
for iseq_reflector = min_reflector_seq upto max_reflector_seq:
   reflector_seqs[iseq_reflector] := (2u, -u * reflector_seq_offset[iseq_reflector]);
   label.(decimal(iseq_reflector), reflector_seqs[iseq_reflector]);
endfor;
for i_received = 0 upto nb_receiveds - 1:
    iseq_sender := xpart receiveds[i_received];
    iseq_reflector := ypart receiveds[i_received];
    draw sender_seqs[iseq_sender]--reflector_seqs[iseq_reflector];
    if i_received = 0:
        received_offset[0] := reflector_seq_offset[iseq_reflector];
    else:
        received_offset[i_received] := max(reflector_seq_offset[iseq_reflector], received_offset[i_received - 1] + 1);
    fi;
    received_places[i_received] := (3u, -u * received_offset[i_received]);
    draw reflector_seqs[iseq_reflector]--received_places[i_received];
    label.rt(decimal(xpart receiveds[i_received]) & "," & decimal(ypart receiveds[i_received]), received_places[i_received]);
endfor;
endfig;
end
EOF


docker run -it --name texlive --rm -v "$OUT_DIR:/workdir" texlive/texlive mpost "$PCAP_BASE.mp"; 

