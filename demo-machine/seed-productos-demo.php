<?php
/**
 * Enriquece los datos de demo con productos de servicio con COSTE, y vincula
 * las líneas de factura existentes a esos productos, para que el ERP pueda
 * calcular beneficio/margen por producto.
 *
 * Ejecutar:  pkexec runuser -u www-data -- php seed-productos-demo.php
 * Idempotente: si el producto ya existe no lo duplica.
 */

use FacturaScripts\Core\Base\DataBase;
use FacturaScripts\Core\Base\DataBase\DataBaseWhere;
use FacturaScripts\Core\Kernel;
use FacturaScripts\Core\Model\Producto;
use FacturaScripts\Core\Plugins;

const FS_FOLDER = '/var/www/html/facturas';
require_once FS_FOLDER . '/vendor/autoload.php';
require_once FS_FOLDER . '/config.php';
Kernel::init();
Plugins::init();

// referencia => [descripcion (igual que la línea de factura), coste unitario, precio orientativo]
$productos = [
    'SRV-HOSTING' => ['Mantenimiento web y hosting', 45, 135],
    'SRV-WEB' => ['Desarrollo de página web', 600, 1500],
    'SRV-RRSS' => ['Gestión de redes sociales (mensual)', 90, 250],
    'SRV-SOLWEDOS' => ['Instalación Solwed OS + soporte', 150, 575],
    'SRV-ERP' => ['Licencia ERP y soporte (mensual)', 60, 300],
    'SRV-ADS' => ['Campaña de publicidad online', 250, 900],
];

$db = new DataBase();
$db->connect();

foreach ($productos as $referencia => [$descripcion, $coste, $precio]) {
    $existentes = (new Producto())->all([new DataBaseWhere('referencia', $referencia)]);
    $producto = $existentes[0] ?? new Producto();
    if (empty($producto->idproducto)) {
        $producto->referencia = $referencia;
        $producto->descripcion = $descripcion;
        $producto->precio = $precio;
        $producto->secompra = false;
        $producto->sevende = true;
        $producto->nostock = true;
        if (false === $producto->save()) {
            exit("ERROR creando $referencia\n");
        }
    }

    // coste en la variante
    $db->exec("UPDATE variantes SET coste = " . (float)$coste . ", precio = " . (float)$precio
        . " WHERE idproducto = " . (int)$producto->idproducto);

    // vincular las líneas de factura existentes por descripción
    $db->exec("UPDATE lineasfacturascli SET referencia = " . $db->var2str($referencia)
        . ", idproducto = " . (int)$producto->idproducto
        . ", coste = " . (float)$coste
        . " WHERE descripcion = " . $db->var2str($descripcion));

    echo "$referencia listo (coste $coste €)\n";
}

$rows = $db->select("SELECT COUNT(*) n FROM lineasfacturascli WHERE referencia IS NOT NULL");
echo "Líneas de venta vinculadas a producto: {$rows[0]['n']}\n";
