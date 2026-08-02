<?php
/**
 * Carga datos de demostración en el FacturaScripts de la máquina de demo:
 * clientes, proveedores y 12 meses de facturas de venta/compra con IVA,
 * usando los modelos de FS para que totales, recibos y ejercicios queden bien.
 *
 * Ejecutar como el usuario del servidor web:
 *   pkexec runuser -u www-data -- php demo-machine/seed-facturascripts-demo.php
 *
 * Es idempotente a nivel práctico: si ya hay facturas, no hace nada.
 */

use FacturaScripts\Core\Kernel;
use FacturaScripts\Core\Lib\Calculator;
use FacturaScripts\Core\Model\Almacen;
use FacturaScripts\Core\Model\Cliente;
use FacturaScripts\Core\Model\Empresa;
use FacturaScripts\Core\Model\FacturaCliente;
use FacturaScripts\Core\Model\FacturaProveedor;
use FacturaScripts\Core\Model\Proveedor;
use FacturaScripts\Core\Plugins;
use FacturaScripts\Core\Tools;

const FS_FOLDER = '/var/www/html/facturas';
require_once FS_FOLDER . '/vendor/autoload.php';
require_once FS_FOLDER . '/config.php';
@set_time_limit(0);
date_default_timezone_set('Europe/Madrid');
Kernel::init();
Plugins::init();

mt_srand(2026); // datos reproducibles

// --- empresa y almacén por defecto ---
$empresa = new Empresa();
if (0 === $empresa->count()) {
    $empresa->nombre = 'Solwed Demo SL';
    $empresa->nombrecorto = 'Solwed Demo';
    $empresa->cifnif = 'B00000000';
    $empresa->direccion = 'Calle Mayor 1';
    $empresa->ciudad = 'Madrid';
    $empresa->codpais = 'ESP';
    if (!$empresa->save()) {
        exit("ERROR: no se pudo crear la empresa\n");
    }
    echo "Empresa creada\n";
} else {
    $empresa->loadFromCode('1');
}

$almacen = new Almacen();
if (0 === $almacen->count()) {
    $almacen->nombre = 'Almacén principal';
    $almacen->idempresa = $empresa->idempresa;
    if (!$almacen->save()) {
        exit("ERROR: no se pudo crear el almacén\n");
    }
    echo "Almacén creado\n";
}

// --- ajustes por defecto que normalmente fija el asistente del primer login ---
$almacenes = (new Almacen())->all();
Tools::settingsSet('default', 'codalmacen', $almacenes[0]->codalmacen);
Tools::settingsSet('default', 'idempresa', $empresa->idempresa);
Tools::settingsSet('default', 'codserie', 'A');
Tools::settingsSet('default', 'coddivisa', 'EUR');
Tools::settingsSet('default', 'codpais', 'ESP');
Tools::settingsSet('default', 'codpago', 'CONT');
Tools::settingsSet('default', 'codimpuesto', 'IVA21');
Tools::settingsSave();

// --- si ya hay facturas, no repetir ---
$facturaTest = new FacturaCliente();
if ($facturaTest->count() > 0) {
    exit("Ya hay facturas: nada que hacer.\n");
}

// --- clientes ---
$nombresClientes = [
    ['Talleres Hermanos Ruiz SL', 'B11111111'],
    ['Clínica Dental Sonrisa SL', 'B22222222'],
    ['Asesoría Fiscal Montero SL', 'B33333333'],
    ['Panadería La Espiga SL', 'B44444444'],
    ['Ferretería El Tornillo SL', 'B55555555'],
    ['Academia Idiomas Global SL', 'B66666666'],
    ['Transportes Vega e Hijos SL', 'B77777777'],
    ['Floristería Pétalos SL', 'B88888888'],
    ['Inmobiliaria Centro Sur SL', 'B99999999'],
    ['Restaurante Casa Paco SL', 'B10101010'],
];
$clientes = (new Cliente())->all([], [], 0, 0);
if (empty($clientes)) {
    foreach ($nombresClientes as [$nombre, $cif]) {
        $c = new Cliente();
        $c->nombre = $nombre;
        $c->razonsocial = $nombre;
        $c->cifnif = $cif;
        if ($c->save()) {
            $clientes[] = $c;
        }
    }
}
echo count($clientes) . " clientes\n";

// --- proveedores ---
$nombresProveedores = [
    ['Hosting Ibérico SL', 'B12121212'],
    ['Suministros Oficina Plus SL', 'B13131313'],
    ['Energía Eléctrica del Sur SA', 'A14141414'],
    ['Telecomunicaciones Rápidas SA', 'A15151515'],
];
$proveedores = (new Proveedor())->all([], [], 0, 0);
if (empty($proveedores)) {
    foreach ($nombresProveedores as [$nombre, $cif]) {
        $p = new Proveedor();
        $p->nombre = $nombre;
        $p->razonsocial = $nombre;
        $p->cifnif = $cif;
        if ($p->save()) {
            $proveedores[] = $p;
        }
    }
}
echo count($proveedores) . " proveedores\n";

$servicios = [
    ['Mantenimiento web y hosting', 90, 180],
    ['Desarrollo de página web', 600, 2400],
    ['Gestión de redes sociales (mensual)', 150, 350],
    ['Instalación Solwed OS + soporte', 250, 900],
    ['Licencia ERP y soporte (mensual)', 120, 480],
    ['Campaña de publicidad online', 300, 1500],
];
$compras = [
    ['Servidores y hosting mayorista', 200, 500],
    ['Material de oficina', 40, 160],
    ['Suministro eléctrico', 90, 220],
    ['Fibra y telefonía', 60, 140],
];

// --- 12 meses de facturas: sep-2025 .. ago-2026, con tendencia creciente ---
$meses = [];
for ($i = 11; $i >= 0; $i--) {
    $meses[] = date('Y-m', strtotime("2026-08-01 -$i months"));
}

$totalVentas = 0;
$totalCompras = 0;
foreach ($meses as $idx => $mes) {
    $numVentas = 4 + intdiv($idx, 3) + mt_rand(0, 2); // más facturas según avanza el año
    // FS exige fechas en orden dentro de cada serie: generar los días ordenados
    $diasVenta = [];
    for ($n = 0; $n < $numVentas; $n++) {
        $diasVenta[] = mt_rand(1, 28);
    }
    sort($diasVenta);
    foreach ($diasVenta as $diaNum) {
        $cliente = $clientes[mt_rand(0, count($clientes) - 1)];
        $dia = str_pad((string)$diaNum, 2, '0', STR_PAD_LEFT);
        $factura = new FacturaCliente();
        $factura->setSubject($cliente);
        $factura->setDate("$dia-" . substr($mes, 5, 2) . "-" . substr($mes, 0, 4), '10:00:00');
        if (!$factura->save()) {
            echo "aviso: factura de venta no guardada ($mes)\n";
            continue;
        }
        $lineas = [];
        $numLineas = mt_rand(1, 3);
        for ($l = 0; $l < $numLineas; $l++) {
            [$desc, $min, $max] = $servicios[mt_rand(0, count($servicios) - 1)];
            $linea = $factura->getNewLine();
            $linea->descripcion = $desc;
            $linea->cantidad = 1;
            $linea->pvpunitario = mt_rand($min, $max);
            $lineas[] = $linea;
        }
        Calculator::calculate($factura, $lineas, true);
        $totalVentas++;

        // ~75% cobradas; el mes en curso queda casi todo pendiente
        $probPagada = ($idx >= 10) ? 30 : 75;
        if (mt_rand(1, 100) <= $probPagada) {
            foreach ($factura->getReceipts() as $recibo) {
                $recibo->pagado = true;
                $recibo->save();
            }
        }
    }

    $numCompras = 2 + mt_rand(0, 2);
    $diasCompra = [];
    for ($n = 0; $n < $numCompras; $n++) {
        $diasCompra[] = mt_rand(1, 28);
    }
    sort($diasCompra);
    foreach ($diasCompra as $diaNum) {
        $proveedor = $proveedores[mt_rand(0, count($proveedores) - 1)];
        $dia = str_pad((string)$diaNum, 2, '0', STR_PAD_LEFT);
        $factura = new FacturaProveedor();
        $factura->setSubject($proveedor);
        $factura->setDate("$dia-" . substr($mes, 5, 2) . "-" . substr($mes, 0, 4), '09:00:00');
        if (!$factura->save()) {
            echo "aviso: factura de compra no guardada ($mes)\n";
            continue;
        }
        [$desc, $min, $max] = $compras[mt_rand(0, count($compras) - 1)];
        $linea = $factura->getNewLine();
        $linea->descripcion = $desc;
        $linea->cantidad = 1;
        $linea->pvpunitario = mt_rand($min, $max);
        $lineasCompra = [$linea];
        Calculator::calculate($factura, $lineasCompra, true);
        $totalCompras++;

        foreach ($factura->getReceipts() as $recibo) {
            $recibo->pagado = mt_rand(1, 100) <= 90;
            $recibo->save();
        }
    }
}

echo "$totalVentas facturas de venta y $totalCompras de compra creadas.\n";
echo "Datos de demo cargados.\n";
