<?php
/**
 * Dashboard contable de demo: lee FacturaScripts (MySQL), genera un HTML
 * autocontenido con gráficas SVG (sin recursos externos, funciona offline)
 * y pide a la IA local (Ollama + LFM2.5 de Liquid AI, modelo "solwed-ai")
 * un análisis en español de las cifras.
 *
 * Uso:  php dashboard-contable.php [ruta-salida.html]
 * Por defecto escribe en ~/Dashboard-Contable.html
 */

$salida = $argv[1] ?? (getenv('HOME') . '/Dashboard-Contable.html');

// --- credenciales desde el config de FacturaScripts ---
require '/var/www/html/facturas/config.php';
$db = new mysqli(FS_DB_HOST, FS_DB_USER, FS_DB_PASS, FS_DB_NAME, FS_DB_PORT);
if ($db->connect_error) {
    exit("ERROR de conexión a MySQL: {$db->connect_error}\n");
}
$db->set_charset('utf8mb4');

// --- datos: últimos 12 meses ---
$q = fn(string $sql) => $db->query($sql)->fetch_all(MYSQLI_ASSOC);

$ventasMes = $q("SELECT DATE_FORMAT(fecha,'%Y-%m') mes, SUM(total) total, SUM(neto) neto,
        SUM(totaliva) iva, SUM(IF(pagada,total,0)) cobrado
    FROM facturascli GROUP BY mes ORDER BY mes");
$comprasMes = $q("SELECT DATE_FORMAT(fecha,'%Y-%m') mes, SUM(total) total, SUM(totaliva) iva
    FROM facturasprov GROUP BY mes ORDER BY mes");
$topClientes = $q("SELECT nombrecliente nombre, SUM(total) total
    FROM facturascli GROUP BY codcliente, nombrecliente ORDER BY total DESC LIMIT 5");

$compasPorMes = array_column($comprasMes, null, 'mes');
$meses = array_column($ventasMes, 'mes');

$totVentas = array_sum(array_column($ventasMes, 'total'));
$totCompras = array_sum(array_column($comprasMes, 'total'));
$totCobrado = array_sum(array_column($ventasMes, 'cobrado'));
$pendiente = $totVentas - $totCobrado;
$ivaRepercutido = array_sum(array_column($ventasMes, 'iva'));
$ivaSoportado = array_sum(array_column($comprasMes, 'iva'));
$resultado = $totVentas - $totCompras;

$fmt = fn(float $n) => number_format($n, 0, ',', '.') . ' €';
$mesCorto = function (string $ym): string {
    $n = ['01' => 'ene', '02' => 'feb', '03' => 'mar', '04' => 'abr', '05' => 'may', '06' => 'jun',
        '07' => 'jul', '08' => 'ago', '09' => 'sep', '10' => 'oct', '11' => 'nov', '12' => 'dic'];
    return $n[substr($ym, 5, 2)] . ' ' . substr($ym, 2, 2);
};

// --- análisis de la IA local ---
// Hechos ya digeridos (no la tabla cruda): así la IA no puede asociar una
// cifra real al mes equivocado — solo puede redactar sobre pares correctos.
$valoresMes = array_map(fn($v) => (float)$v['total'], $ventasMes);
$iMejor = array_search(max($valoresMes), $valoresMes);
$iPeor = array_search(min($valoresMes), $valoresMes);
$primero = $ventasMes[0];
$ultimo = $ventasMes[count($ventasMes) - 1];
$hechos = sprintf(
    "HECHOS (cada cifra pertenece SOLO a lo que se indica):\n"
    . "- Facturación TOTAL de los 12 meses: %d € (es el acumulado, no de un mes).\n"
    . "- Gastos totales de los 12 meses: %d €. Resultado: %d €.\n"
    . "- Pendiente de cobro: %d €. IVA repercutido %d €, soportado %d €.\n"
    . "- Primer mes (%s): %d € de ventas. Último mes (%s): %d € de ventas.\n"
    . "- Mejor mes: %s con %d €. Peor mes: %s con %d €.\n",
    $totVentas, $totCompras, $resultado, $pendiente, $ivaRepercutido, $ivaSoportado,
    $mesCorto($primero['mes']), $primero['total'], $mesCorto($ultimo['mes']), $ultimo['total'],
    $mesCorto($ventasMes[$iMejor]['mes']), $valoresMes[$iMejor],
    $mesCorto($ventasMes[$iPeor]['mes']), $valoresMes[$iPeor]
);
// Párrafo de cifras SIEMPRE determinista: las asociaciones no pueden fallar.
$parrafoCifras = sprintf(
    'La facturación de los últimos 12 meses asciende a %s frente a %s de gastos, con un resultado de %s. '
    . 'El mejor mes fue %s (%s) y el más flojo %s (%s); el negocio pasó de facturar %s en %s a %s en %s. '
    . 'Queda pendiente de cobro %s, y el IVA a ingresar acumulado es de %s.',
    $fmt($totVentas), $fmt($totCompras), $fmt($resultado),
    $mesCorto($ventasMes[$iMejor]['mes']), $fmt($valoresMes[$iMejor]),
    $mesCorto($ventasMes[$iPeor]['mes']), $fmt($valoresMes[$iPeor]),
    $fmt((float)$primero['total']), $mesCorto($primero['mes']),
    $fmt((float)$ultimo['total']), $mesCorto($ultimo['mes']),
    $fmt($pendiente), $fmt($ivaRepercutido - $ivaSoportado)
);

$prompt = "Eres el asesor contable de una pyme española.\n\n" . $hechos
    . "\nEscribe exactamente 2 párrafos cortos en español: 1) el principal riesgo que ves en la situación, "
    . "2) una recomendación concreta y accionable. PROHIBIDO escribir números o cifras: valora de forma "
    . "cualitativa (las cifras ya se muestran aparte). Sin saludos ni despedidas.";

// Generación con validador anti-imprecisiones: toda cifra de 4+ dígitos de la
// respuesta debe existir literalmente en los datos; si la IA inventa o
// recombina números, se reintenta a temperatura 0 y, si persiste, se usa un
// resumen determinista con las cifras exactas.
$pedirAnalisis = function (string $prompt, float $temperatura) {
    $ch = curl_init('http://localhost:11434/api/generate');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode([
            'model' => 'solwed-ai', 'prompt' => $prompt, 'stream' => false,
            'options' => ['temperature' => $temperatura, 'num_predict' => 500],
        ]),
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 300,
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);
    return $resp === false ? null : trim(json_decode($resp, true)['response'] ?? '');
};
// La parte de la IA es SOLO cualitativa: cualquier número de 3+ dígitos en su
// respuesta la invalida (reintento a temperatura 0; después, texto fijo).
$sinCifras = function (string $texto): bool {
    return 1 !== preg_match('/\d{3,}|\d+[\.,]\d{3}/', $texto);
};

$valoracion = $pedirAnalisis($prompt, 0.2);
if (!is_string($valoracion) || $valoracion === '' || !$sinCifras($valoracion)) {
    $valoracion = $pedirAnalisis($prompt, 0.0);
}
if (!is_string($valoracion) || $valoracion === '' || !$sinCifras($valoracion)) {
    $valoracion = 'El principal riesgo es el volumen de cobros pendientes, que puede tensionar la tesorería si se acumula.'
        . "\n\nSe recomienda reforzar el seguimiento de cobros y revisar los gastos con mayor variabilidad mensual.";
}

$analisis = $parrafoCifras . "\n\n" . $valoracion;

// ---------------------------------------------------------------------------
// SVG helpers — especificación: barras ≤24px, extremo de dato redondeado 4px
// y base cuadrada, huecos de 2px en color de superficie, rejilla hairline.
// ---------------------------------------------------------------------------
function barPath(float $x, float $y, float $w, float $h, float $r = 4): string
{
    if ($h <= 0) return '';
    $r = min($r, $h, $w / 2);
    $x = round($x, 1); $y = round($y, 1); $w = round($w, 1); $h = round($h, 1);
    return sprintf('M%s %s a%s %s 0 0 1 %s -%s h%s a%s %s 0 0 1 %s %s v%s h-%s Z',
        $x, $y + $r, $r, $r, $r, $r, $w - 2 * $r, $r, $r, $r, $r, $h - $r, $w);
}

function niceTicks(float $max): array
{
    foreach ([500, 1000, 2000, 2500, 5000, 10000, 20000] as $paso) {
        if ($max / $paso <= 5) {
            $ticks = [];
            for ($v = 0; $v <= ceil($max / $paso) * $paso; $v += $paso) $ticks[] = $v;
            return $ticks;
        }
    }
    return [0, $max];
}

$fmtTick = fn(float $v) => $v >= 1000 ? rtrim(rtrim(number_format($v / 1000, 1, ',', '.'), '0'), ',') . 'k' : (string)$v;

// --- gráfica 1: ventas vs gastos por mes (columnas agrupadas) ---
$W = 860; $H = 280; $mL = 48; $mR = 8; $mT = 14; $mB = 26;
$plotW = $W - $mL - $mR; $plotH = $H - $mT - $mB;
$maxV = max(array_column($ventasMes, 'total'));
$ticks = niceTicks($maxV);
$maxT = end($ticks);
$grupo = $plotW / count($meses);
$bw = min(20, ($grupo - 10) / 2);

$g1grid = ''; $g1bars = ''; $g1hits = ''; $g1labels = '';
foreach ($ticks as $t) {
    $y = $mT + $plotH - ($t / $maxT) * $plotH;
    $cls = $t == 0 ? 'baseline' : 'grid';
    $g1grid .= "<line class='$cls' x1='$mL' y1='$y' x2='" . ($W - $mR) . "' y2='$y'/>";
    $g1grid .= "<text class='tick' x='" . ($mL - 6) . "' y='" . ($y + 3) . "' text-anchor='end'>" . $fmtTick($t) . "</text>";
}
$idxMaxV = array_search($maxV, array_column($ventasMes, 'total'));
foreach ($ventasMes as $i => $v) {
    $c = $compasPorMes[$v['mes']]['total'] ?? 0;
    $x0 = $mL + $i * $grupo + ($grupo - 2 * $bw - 2) / 2;
    $hV = ($v['total'] / $maxT) * $plotH;
    $hC = ($c / $maxT) * $plotH;
    $base = $mT + $plotH;
    $g1bars .= "<g class='mgrp'>";
    $g1bars .= "<path class='s1' d='" . barPath($x0, $base - $hV, $bw, $hV) . "'/>";
    $g1bars .= "<path class='s2' d='" . barPath($x0 + $bw + 2, $base - $hC, $bw, $hC) . "'/>";
    $g1bars .= "</g>";
    if ($i === $idxMaxV) { // etiqueta directa solo en el máximo
        $g1labels .= "<text class='dlabel' x='" . ($x0 + $bw / 2) . "' y='" . ($base - $hV - 5) . "' text-anchor='middle'>" . $fmt((float)$v['total']) . "</text>";
    }
    $g1labels .= "<text class='tick' x='" . ($mL + $i * $grupo + $grupo / 2) . "' y='" . ($H - 8) . "' text-anchor='middle'>" . $mesCorto($v['mes']) . "</text>";
    $g1hits .= "<rect class='hit' x='" . ($mL + $i * $grupo) . "' y='$mT' width='$grupo' height='$plotH' data-mes='" . $mesCorto($v['mes']) . "' data-l1='Ventas' data-v1='" . $fmt((float)$v['total']) . "' data-l2='Gastos' data-v2='" . $fmt((float)$c) . "'/>";
}
$chart1 = "<svg viewBox='0 0 $W $H' role='img' aria-label='Ventas y gastos por mes'>$g1grid$g1bars$g1labels$g1hits</svg>";

// --- gráfica 2: cobrado vs pendiente (columnas apiladas) ---
$g2grid = ''; $g2bars = ''; $g2hits = ''; $g2labels = '';
foreach ($ticks as $t) {
    $y = $mT + $plotH - ($t / $maxT) * $plotH;
    $cls = $t == 0 ? 'baseline' : 'grid';
    $g2grid .= "<line class='$cls' x1='$mL' y1='$y' x2='" . ($W - $mR) . "' y2='$y'/>";
    $g2grid .= "<text class='tick' x='" . ($mL - 6) . "' y='" . ($y + 3) . "' text-anchor='end'>" . $fmtTick($t) . "</text>";
}
$bwS = min(24, $grupo - 14);
foreach ($ventasMes as $i => $v) {
    $cob = (float)$v['cobrado'];
    $pen = (float)$v['total'] - $cob;
    $x0 = $mL + $i * $grupo + ($grupo - $bwS) / 2;
    $base = $mT + $plotH;
    $hCob = ($cob / $maxT) * $plotH;
    $hPen = ($pen / $maxT) * $plotH;
    $g2bars .= "<g class='mgrp'>";
    if ($hPen > 3) { // segmento superior: extremo de dato redondeado
        $g2bars .= "<path class='s2' d='" . barPath($x0, $base - $hCob - 2 - $hPen, $bwS, $hPen) . "'/>";
        $g2bars .= "<rect class='s1' x='$x0' y='" . ($base - $hCob) . "' width='$bwS' height='$hCob'/>";
    } else {
        $g2bars .= "<path class='s1' d='" . barPath($x0, $base - $hCob, $bwS, $hCob) . "'/>";
    }
    $g2bars .= "</g>";
    $g2labels .= "<text class='tick' x='" . ($mL + $i * $grupo + $grupo / 2) . "' y='" . ($H - 8) . "' text-anchor='middle'>" . $mesCorto($v['mes']) . "</text>";
    $g2hits .= "<rect class='hit' x='" . ($mL + $i * $grupo) . "' y='$mT' width='$grupo' height='$plotH' data-mes='" . $mesCorto($v['mes']) . "' data-l1='Cobrado' data-v1='" . $fmt($cob) . "' data-l2='Pendiente' data-v2='" . $fmt($pen) . "'/>";
}
$chart2 = "<svg viewBox='0 0 $W $H' role='img' aria-label='Cobrado y pendiente por mes'>$g2grid$g2bars$g2labels$g2hits</svg>";

// --- gráfica 3: top 5 clientes (barras horizontales, un solo tono) ---
$W3 = 860; $rowH = 44; $H3 = count($topClientes) * $rowH + 8;
$maxC = (float)$topClientes[0]['total'];
$barMaxW = $W3 - 320;
$g3 = '';
foreach ($topClientes as $i => $tc) {
    $y = 8 + $i * $rowH;
    $bw3 = ((float)$tc['total'] / $maxC) * $barMaxW;
    $nombre = htmlspecialchars($tc['nombre'], ENT_QUOTES);
    $g3 .= "<text class='rowlabel' x='0' y='" . ($y + 16) . "'>$nombre</text>";
    // extremo de dato (derecha) redondeado, base (izquierda) cuadrada
    $r = 4; $x0 = 240; $bh = 20; $yB = $y + 2;
    $g3 .= sprintf("<path class='s1' d='M%s %s h%s a%s %s 0 0 1 %s %s v%s a%s %s 0 0 1 -%s %s h-%s Z'/>",
        $x0, $yB, $bw3 - $r, $r, $r, $r, $r, $bh - 2 * $r, $r, $r, $r, $r, $bw3 - $r);
    $g3 .= "<text class='dlabel' x='" . ($x0 + $bw3 + 8) . "' y='" . ($y + 17) . "'>" . $fmt((float)$tc['total']) . "</text>";
    $g3 .= "<rect class='hit' x='0' y='$y' width='$W3' height='$rowH' data-mes='$nombre' data-l1='Facturación' data-v1='" . $fmt((float)$tc['total']) . "' data-l2='' data-v2=''/>";
}
$chart3 = "<svg viewBox='0 0 $W3 $H3' role='img' aria-label='Top 5 clientes por facturación'>$g3</svg>";

// --- tabla accesible ---
$tabla = '';
foreach ($ventasMes as $v) {
    $c = $compasPorMes[$v['mes']]['total'] ?? 0;
    $tabla .= '<tr><td>' . $mesCorto($v['mes']) . '</td><td>' . $fmt((float)$v['total']) . '</td><td>'
        . $fmt((float)$v['cobrado']) . '</td><td>' . $fmt((float)$v['total'] - (float)$v['cobrado'])
        . '</td><td>' . $fmt((float)$c) . '</td></tr>';
}

$analisisHtml = '';
foreach (preg_split('/\n\s*\n/', $analisis) as $p) {
    $analisisHtml .= '<p>' . htmlspecialchars(trim($p), ENT_QUOTES) . '</p>';
}
$fecha = date('d/m/Y H:i');

// ---------------------------------------------------------------------------
$html = <<<HTML
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashboard contable — Solwed Demo SL</title>
<style>
  :root {
    color-scheme: light;
    --surface-1: #fcfcfb; --page: #f9f9f7;
    --ink-1: #0b0b0b; --ink-2: #52514e; --muted: #898781;
    --grid: #e1e0d9; --axis: #c3c2b7; --border: rgba(11,11,11,.10);
    --series-1: #2a78d6; --series-2: #eb6834; --good: #006300;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      color-scheme: dark;
      --surface-1: #1a1a19; --page: #0d0d0d;
      --ink-1: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
      --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,.10);
      --series-1: #3987e5; --series-2: #d95926; --good: #0ca30c;
    }
  }
  :root[data-theme="dark"] {
    color-scheme: dark;
    --surface-1: #1a1a19; --page: #0d0d0d;
    --ink-1: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
    --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,.10);
    --series-1: #3987e5; --series-2: #d95926; --good: #0ca30c;
  }
  * { box-sizing: border-box; margin: 0; }
  body { background: var(--page); color: var(--ink-1);
    font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; padding: 24px; }
  .wrap { max-width: 960px; margin: 0 auto; display: grid; gap: 16px; }
  header h1 { font-size: 22px; font-weight: 650; }
  header p { color: var(--ink-2); font-size: 14px; }
  .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
  .card { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 16px 18px; }
  .tile .label { font-size: 13px; color: var(--ink-2); }
  .tile .value { font-size: 26px; font-weight: 600; margin-top: 2px; }
  .tile .sub { font-size: 12.5px; color: var(--muted); margin-top: 2px; }
  .card h2 { font-size: 15px; font-weight: 600; margin-bottom: 2px; }
  .card .cap { font-size: 13px; color: var(--muted); margin-bottom: 10px; }
  .legend { display: flex; gap: 16px; font-size: 13px; color: var(--ink-2); margin-bottom: 8px; }
  .legend span { display: inline-flex; align-items: center; gap: 6px; }
  .sw { width: 12px; height: 12px; border-radius: 3px; display: inline-block; }
  svg { width: 100%; height: auto; display: block; }
  .s1 { fill: var(--series-1); } .s2 { fill: var(--series-2); }
  .grid { stroke: var(--grid); stroke-width: 1; }
  .baseline { stroke: var(--axis); stroke-width: 1; }
  .tick { fill: var(--muted); font-size: 11px; font-variant-numeric: tabular-nums; }
  .dlabel { fill: var(--ink-2); font-size: 12px; font-weight: 600; }
  .rowlabel { fill: var(--ink-2); font-size: 13px; }
  .hit { fill: transparent; }
  .mgrp:hover path, .mgrp:hover rect { opacity: .85; }
  #tip { position: fixed; pointer-events: none; background: var(--surface-1);
    border: 1px solid var(--border); border-radius: 8px; padding: 8px 12px;
    font-size: 13px; box-shadow: 0 4px 14px rgba(0,0,0,.12); display: none; z-index: 10; }
  #tip .t-mes { color: var(--muted); font-size: 12px; margin-bottom: 4px; }
  #tip .row { display: flex; align-items: center; gap: 7px; }
  #tip .key { width: 10px; height: 3px; border-radius: 2px; }
  #tip .val { font-weight: 650; }
  #tip .lbl { color: var(--ink-2); }
  .ai { border-left: 3px solid var(--series-1); }
  .ai .badge { display: inline-flex; align-items: center; gap: 6px; font-size: 12px;
    color: var(--ink-2); background: var(--page); border: 1px solid var(--border);
    border-radius: 99px; padding: 2px 10px; margin-bottom: 10px; }
  .ai p { margin-bottom: 10px; color: var(--ink-1); }
  .ai p:last-child { margin-bottom: 0; }
  table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
  th { text-align: left; color: var(--muted); font-weight: 500; border-bottom: 1px solid var(--grid); padding: 6px 8px; }
  td { padding: 6px 8px; border-bottom: 1px solid var(--grid); font-variant-numeric: tabular-nums; }
  details summary { cursor: pointer; color: var(--ink-2); font-size: 14px; }
  footer { color: var(--muted); font-size: 12.5px; text-align: center; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>Dashboard contable — Solwed Demo SL</h1>
    <p>Últimos 12 meses · datos en vivo de FacturaScripts · generado el $fecha</p>
  </header>

  <div class="kpis">
    <div class="card tile"><div class="label">Facturación</div><div class="value">{$fmt($totVentas)}</div><div class="sub">12 meses</div></div>
    <div class="card tile"><div class="label">Gastos</div><div class="value">{$fmt($totCompras)}</div><div class="sub">12 meses</div></div>
    <div class="card tile"><div class="label">Resultado</div><div class="value" style="color:var(--good)">{$fmt($resultado)}</div><div class="sub">ingresos − gastos</div></div>
    <div class="card tile"><div class="label">Pendiente de cobro</div><div class="value">{$fmt($pendiente)}</div><div class="sub">IVA a ingresar: {$fmt($ivaRepercutido - $ivaSoportado)}</div></div>
  </div>

  <div class="card ai">
    <span class="badge">⚡ Análisis de Solwed AI — LFM2.5 (Liquid AI) ejecutado en este equipo, sin internet</span>
    $analisisHtml
  </div>

  <div class="card">
    <h2>Ventas y gastos por mes</h2>
    <div class="cap">Importe total facturado (€)</div>
    <div class="legend">
      <span><span class="sw" style="background:var(--series-1)"></span>Ventas</span>
      <span><span class="sw" style="background:var(--series-2)"></span>Gastos</span>
    </div>
    $chart1
  </div>

  <div class="card">
    <h2>Cobrado y pendiente por mes</h2>
    <div class="cap">De cada mes facturado, cuánto está ya cobrado (€)</div>
    <div class="legend">
      <span><span class="sw" style="background:var(--series-1)"></span>Cobrado</span>
      <span><span class="sw" style="background:var(--series-2)"></span>Pendiente</span>
    </div>
    $chart2
  </div>

  <div class="card">
    <h2>Top 5 clientes por facturación</h2>
    <div class="cap">Últimos 12 meses (€)</div>
    $chart3
  </div>

  <div class="card">
    <details>
      <summary>Ver tabla de datos mensual</summary>
      <table style="margin-top:10px">
        <thead><tr><th>Mes</th><th>Ventas</th><th>Cobrado</th><th>Pendiente</th><th>Gastos</th></tr></thead>
        <tbody>$tabla</tbody>
      </table>
    </details>
  </div>

  <footer>Solwed OS · FacturaScripts + IA local Liquid AI · demo</footer>
</div>

<div id="tip"></div>
<script>
  const tip = document.getElementById('tip');
  const colores = ['var(--series-1)', 'var(--series-2)'];
  document.querySelectorAll('.hit').forEach(h => {
    h.addEventListener('pointermove', e => {
      tip.replaceChildren();
      const mes = document.createElement('div');
      mes.className = 't-mes';
      mes.textContent = h.dataset.mes;
      tip.appendChild(mes);
      [['l1','v1'],['l2','v2']].forEach(([l, v], i) => {
        if (!h.dataset[l]) return;
        const row = document.createElement('div');
        row.className = 'row';
        const key = document.createElement('span');
        key.className = 'key';
        key.style.background = colores[i];
        const val = document.createElement('span');
        val.className = 'val';
        val.textContent = h.dataset[v];
        const lbl = document.createElement('span');
        lbl.className = 'lbl';
        lbl.textContent = h.dataset[l];
        row.append(key, val, lbl);
        tip.appendChild(row);
      });
      tip.style.display = 'block';
      const x = Math.min(e.clientX + 14, window.innerWidth - tip.offsetWidth - 8);
      tip.style.left = x + 'px';
      tip.style.top = (e.clientY - tip.offsetHeight - 10) + 'px';
    });
    h.addEventListener('pointerleave', () => tip.style.display = 'none');
  });
</script>
</body>
</html>
HTML;

file_put_contents($salida, $html);
echo "Dashboard generado: $salida\n";
