-- ARCHIVO: 02_Consultas_Avanzadas.sql
USE ecommerce_db;

-- 1. Top 10 Productos Más Vendidos (っ◕‿◕)っ
SELECT 
    productos.nombre AS producto,
    SUM(detalle_ventas.cantidad * detalle_ventas.precio_unitario_congelado) AS ingresos_totales,
    SUM(detalle_ventas.cantidad) AS unidades_vendidas
FROM detalle_ventas
INNER JOIN productos ON detalle_ventas.id_producto = productos.id_producto
GROUP BY productos.nombre
ORDER BY ingresos_totales DESC
LIMIT 10;


-- 2. Productos con Bajas Ventas (._.)
SELECT 
    productos.nombre AS producto,
    IFNULL(SUM(detalle_ventas.cantidad), 0) AS total_vendido
FROM productos
LEFT JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
GROUP BY productos.nombre
ORDER BY total_vendido ASC
LIMIT 10;


-- 3. Clientes VIP (─‿‿─)
SELECT 
    clientes.nombre,
    clientes.apellido,
    clientes.email,
    SUM(ventas.total) AS valor_vida_ltv,
    COUNT(ventas.id_venta) AS cantidad_compras
FROM clientes
INNER JOIN ventas ON clientes.id_cliente = ventas.id_cliente
WHERE ventas.estado IN ('Entregado', 'Enviado', 'Procesando')
GROUP BY clientes.id_cliente, clientes.nombre, clientes.apellido, clientes.email
ORDER BY valor_vida_ltv DESC
LIMIT 5;


-- 4. Análisis de Ventas Mensuales O.O
SELECT 
    YEAR(ventas.fecha_venta) AS anio,
    MONTH(ventas.fecha_venta) AS mes,
    SUM(ventas.total) AS ingresos_mensuales,
    COUNT(ventas.id_venta) AS total_pedidos
FROM ventas
WHERE ventas.estado != 'Cancelado'
GROUP BY YEAR(ventas.fecha_venta), MONTH(ventas.fecha_venta)
ORDER BY anio DESC, mes DESC;


-- 5. Crecimiento de Clientes :D
SELECT 
    YEAR(clientes.fecha_registro) AS anio,
    QUARTER(clientes.fecha_registro) AS trimestre,
    COUNT(clientes.id_cliente) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(clientes.fecha_registro), QUARTER(clientes.fecha_registro)
ORDER BY anio DESC, trimestre DESC;


-- 6. Tasa de Compra Repetida -_-
SELECT 
    (COUNT(CASE WHEN compras_por_cliente.compras > 1 THEN 1 END) / COUNT(*)) * 100 AS "Porcentaje Compra Repetida"
FROM (
    SELECT ventas.id_cliente, COUNT(ventas.id_venta) AS compras
    FROM ventas
    GROUP BY ventas.id_cliente
) AS compras_por_cliente;


-- 7. Productos Comprados Juntos Frecuentemente o.o
SELECT 
    productos_1.nombre AS producto_1,
    productos_2.nombre AS producto_2,
    COUNT(*) AS veces_comprados_juntos
FROM detalle_ventas AS detalle_ventas_1
INNER JOIN detalle_ventas AS detalle_ventas_2 
    ON detalle_ventas_1.id_venta = detalle_ventas_2.id_venta 
    AND detalle_ventas_1.id_producto < detalle_ventas_2.id_producto
INNER JOIN productos AS productos_1 
    ON detalle_ventas_1.id_producto = productos_1.id_producto
INNER JOIN productos AS productos_2 
    ON detalle_ventas_2.id_producto = productos_2.id_producto
GROUP BY productos_1.nombre, productos_2.nombre
ORDER BY veces_comprados_juntos DESC
LIMIT 5;


-- 8. Rotación de Inventario - _ -
SELECT 
    categorias.nombre AS categoria,
    SUM(detalle_ventas.cantidad) AS unidades_vendidas_historicas,
    SUM(productos.stock) AS stock_actual_total,
    ROUND(SUM(detalle_ventas.cantidad) / NULLIF(SUM(productos.stock), 0), 2) AS indice_rotacion
FROM categorias
INNER JOIN productos ON categorias.id_categoria = productos.id_categoria
LEFT JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
GROUP BY categorias.nombre
ORDER BY indice_rotacion DESC;


-- 9. Productos que Necesitan Reabastecimiento :(
SELECT 
    productos.nombre,
    productos.sku,
    productos.stock,
    productos.precio
FROM productos
WHERE productos.stock < 15 AND productos.activo = TRUE
ORDER BY productos.stock ASC;


-- 10. Análisis de Carrito Abandonado (╥﹏╥)
SELECT 
    clientes.nombre,
    clientes.email,
    ventas.id_venta,
    ventas.fecha_venta,
    ventas.total
FROM ventas
INNER JOIN clientes ON ventas.id_cliente = clientes.id_cliente
WHERE ventas.estado = 'Pendiente de Pago' 
AND ventas.fecha_venta < NOW() - INTERVAL 24 HOUR;


-- 11. Rendimiento de Proveedores ◕‿◕
SELECT 
    proveedores.nombre AS proveedor,
    COUNT(DISTINCT productos.id_producto) AS productos_ofrecidos,
    SUM(detalle_ventas.cantidad) AS total_unidades_vendidas,
    SUM(detalle_ventas.cantidad * detalle_ventas.precio_unitario_congelado) AS dinero_generado
FROM proveedores
INNER JOIN productos ON proveedores.id_proveedor = productos.id_proveedor
INNER JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
GROUP BY proveedores.nombre
ORDER BY dinero_generado DESC;


-- 12. Análisis Geográfico de Ventas O.O
SELECT 
    TRIM(SUBSTRING_INDEX(clientes.direccion_envio, ',', -1)) AS ciudad,
    COUNT(ventas.id_venta) AS cantidad_pedidos,
    SUM(ventas.total) AS ingresos_totales
FROM clientes
INNER JOIN ventas ON clientes.id_cliente = ventas.id_cliente
GROUP BY ciudad
ORDER BY ingresos_totales DESC;


-- 13. Ventas por Hora del Día
SELECT 
    HOUR(ventas.fecha_venta) AS hora_del_dia,
    COUNT(ventas.id_venta) AS total_pedidos,
    SUM(ventas.total) AS ingresos
FROM ventas
GROUP BY HOUR(ventas.fecha_venta)
ORDER BY total_pedidos DESC;


-- 14. Impacto de Promociones o.o
SELECT 
    productos.nombre AS producto,
    SUM(CASE WHEN MONTH(ventas.fecha_venta) = 11 THEN detalle_ventas.cantidad ELSE 0 END) AS ventas_noviembre_promo,
    SUM(CASE WHEN MONTH(ventas.fecha_venta) = 10 THEN detalle_ventas.cantidad ELSE 0 END) AS ventas_octubre_normal
FROM productos
INNER JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
INNER JOIN ventas ON detalle_ventas.id_venta = ventas.id_venta
GROUP BY productos.nombre
HAVING ventas_noviembre_promo > 0 OR ventas_octubre_normal > 0;


-- 15. Análisis de Cohort (o.o)
WITH PrimeraCompra AS (
    SELECT ventas.id_cliente, MIN(MONTH(ventas.fecha_venta)) AS mes_primera_compra
    FROM ventas
    GROUP BY ventas.id_cliente
)
SELECT 
    PrimeraCompra.mes_primera_compra,
    COUNT(DISTINCT ventas.id_cliente) AS clientes_que_recompraron
FROM PrimeraCompra
INNER JOIN ventas ON PrimeraCompra.id_cliente = ventas.id_cliente
WHERE MONTH(ventas.fecha_venta) > PrimeraCompra.mes_primera_compra
GROUP BY PrimeraCompra.mes_primera_compra;


-- 16. Margen de Beneficio por Producto
SELECT 
    productos.nombre AS producto,
    productos.precio AS precio_venta,
    productos.costo AS precio_compra,
    (productos.precio - productos.costo) AS beneficio_neto,
    ROUND(((productos.precio - productos.costo) / productos.precio) * 100, 2) AS margen_porcentaje
FROM productos
WHERE productos.activo = TRUE
ORDER BY margen_porcentaje DESC;


-- 17. Tiempo Promedio Entre Compras (─‿‿─)
SELECT 
    clientes.nombre,
    AVG(DATEDIFF(ventas_siguiente.fecha_venta, ventas_primera.fecha_venta)) AS dias_promedio_entre_compras
FROM ventas AS ventas_primera
INNER JOIN ventas AS ventas_siguiente 
    ON ventas_primera.id_cliente = ventas_siguiente.id_cliente 
    AND ventas_primera.id_venta < ventas_siguiente.id_venta
INNER JOIN clientes 
    ON ventas_primera.id_cliente = clientes.id_cliente
GROUP BY clientes.id_cliente, clientes.nombre
ORDER BY dias_promedio_entre_compras ASC;


-- 18. Productos Más Vistos vs. Comprados -_-
WITH VistasSimuladas AS (
    SELECT productos.id_producto, FLOOR(RAND() * 1000 + 100) AS cantidad_vistas 
    FROM productos
)
SELECT 
    productos.nombre,
    VistasSimuladas.cantidad_vistas,
    IFNULL(SUM(detalle_ventas.cantidad), 0) AS cantidad_comprada,
    ROUND((IFNULL(SUM(detalle_ventas.cantidad), 0) / VistasSimuladas.cantidad_vistas) * 100, 2) AS tasa_conversion_porcentaje
FROM productos
INNER JOIN VistasSimuladas ON productos.id_producto = VistasSimuladas.id_producto
LEFT JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
GROUP BY productos.id_producto, productos.nombre, VistasSimuladas.cantidad_vistas
ORDER BY tasa_conversion_porcentaje ASC
LIMIT 10;


-- 19. Segmentación de Clientes RFM :D
SELECT 
    clientes.nombre,
    DATEDIFF(NOW(), MAX(ventas.fecha_venta)) AS dias_desde_ultima_compra_Recencia,
    COUNT(ventas.id_venta) AS total_pedidos_Frecuencia,
    SUM(ventas.total) AS total_gastado_Monetario
FROM clientes
INNER JOIN ventas ON clientes.id_cliente = ventas.id_cliente
GROUP BY clientes.id_cliente, clientes.nombre
ORDER BY total_gastado_Monetario DESC, total_pedidos_Frecuencia DESC;


-- 20. Predicción de Demanda Simple
SELECT 
    productos.nombre AS producto,
    categorias.nombre AS categoria,
    productos.stock AS stock_actual,
    ROUND(AVG(detalle_ventas.cantidad), 0) AS demanda_promedio_estimada_mensual,
    CASE 
        WHEN productos.stock < ROUND(AVG(detalle_ventas.cantidad), 0) THEN 'Urgente Reabastecer'
        ELSE 'Stock Saludable'
    END AS estado_prediccion
FROM productos
INNER JOIN categorias ON productos.id_categoria = categorias.id_categoria
INNER JOIN detalle_ventas ON productos.id_producto = detalle_ventas.id_producto
GROUP BY productos.id_producto, productos.nombre, categorias.nombre, productos.stock
ORDER BY demanda_promedio_estimada_mensual DESC;