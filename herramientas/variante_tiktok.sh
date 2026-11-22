#!/usr/bin/env bash
# Crea una versión de TikTok distinta para una sede a partir de un video de anuncio.
# Cambia lo que TikTok compara para detectar contenido repetido:
#   gancho de texto propio en los primeros segundos, encuadre (zoom y posición),
#   color, velocidad y metadatos. La tarjeta final con precio y WhatsApp no se recorta.
#
# Uso:
#   variante_tiktok.sh ENTRADA SALIDA INICIO_TARJETA ZOOM POS_X POS_Y VELOCIDAD COLOR "LINEA 1" "LINEA 2" [FIN_GANCHO]
#     INICIO_TARJETA  segundo donde empieza la tarjeta final (no se le aplica zoom)
#     ZOOM            1.00 = sin zoom, 1.08 = 8 % más cerca
#     POS_X POS_Y     0 a 1: hacia dónde se ancla el recorte (0.5 0.5 = centro)
#     VELOCIDAD       1.00 = normal, 1.04 = 4 % más rápido
#     COLOR           filtro eq de ffmpeg, p. ej. "saturation=1.08:contrast=1.03"
#     FIN_GANCHO      segundos que se muestra el texto del gancho (por defecto 4.4)
set -euo pipefail
IN=$1; OUT=$2; CARD=$3; Z=$4; PX=$5; PY=$6; SPD=$7; EQ=$8; L1=$9; L2=${10}; HOOK=${11:-4.4}
FONT=/usr/share/fonts/opentype/inter/InterDisplay-Black.otf
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf '%s' "$L1" > "$TMP/l1.txt"; printf '%s' "$L2" > "$TMP/l2.txt"
W=$(python3 -c "print(int(1080*$Z)//2*2)"); H=$(python3 -c "print(int(1920*$Z)//2*2)")
CX=$(python3 -c "print(int(($W-1080)*$PX))"); CY=$(python3 -c "print(int(($H-1920)*$PY))")
TXT="drawtext=fontfile=$FONT:textfile=$TMP/l1.txt:fontsize=52:fontcolor=white:box=1:boxcolor=0x14213D:boxborderw=16:x=(w-tw)/2:y=250:enable='lt(t,$HOOK)',drawtext=fontfile=$FONT:textfile=$TMP/l2.txt:fontsize=64:fontcolor=0x14213D:box=1:boxcolor=0xF6C445:boxborderw=20:x=(w-tw)/2:y=345:enable='lt(t,$HOOK)'"
ffmpeg -v error -y -i "$IN" -filter_complex "
[0:v]split=2[a][b];
[a]trim=0:$CARD,setpts=PTS-STARTPTS,scale=$W:$H,crop=1080:1920:$CX:$CY,setsar=1,eq=$EQ,$TXT[pre];
[b]trim=$CARD,setpts=PTS-STARTPTS,setsar=1[card];
[pre][card]concat=n=2:v=1:a=0,setpts=PTS/$SPD,fps=30,format=yuv420p[v];
[0:a]atempo=$SPD[au]" -map "[v]" -map "[au]" -map_metadata -1 \
  -c:v libx264 -preset medium -crf 20 -profile:v high -c:a aac -b:a 128k -movflags +faststart "$OUT"
echo "OK $OUT"
