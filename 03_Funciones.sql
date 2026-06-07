-- ARCHIVO: 03_Funciones.sql
USE ecommerce_db;

-- 1. fn_CalcularTotalVenta
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT) 
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);
    SELECT IFNULL(SUM(detalle_ventas.cantidad * detalle_ventas.precio_unitario_congelado), 0.00) INTO v_total
    FROM detalle_ventas
    WHERE detalle_ventas.id_venta = p_id_venta;
    RETURN v_total;
END;


-- 2. fn_VerificarDisponibilidadStock (._.)
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad_necesaria INT) 
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock_actual INT;
    SELECT productos.stock INTO v_stock_actual
    FROM productos
    WHERE productos.id_producto = p_id_producto;
    IF v_stock_actual >= p_cantidad_necesaria THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;


-- 3. fn_ObtenerPrecioProducto ◕‿◕
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT) 
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    SELECT productos.precio INTO v_precio
    FROM productos
    WHERE productos.id_producto = p_id_producto;
    RETURN v_precio;
END;


-- 4. fn_CalcularEdadCliente
CREATE FUNCTION fn_CalcularEdadCliente(p_fecha_nacimiento DATE) 
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, p_fecha_nacimiento, CURDATE());
END;


-- 5. fn_FormatearNombreCompleto :D
CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(100), p_apellido VARCHAR(100)) 
RETURNS VARCHAR(205)
DETERMINISTIC
BEGIN
    RETURN CONCAT(TRIM(p_nombre), ' ', TRIM(p_apellido));
END;


-- 6. fn_EsClienteNuevo
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT) 
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_fecha_registro DATETIME;
    SELECT clientes.fecha_registro INTO v_fecha_registro
    FROM clientes
    WHERE clientes.id_cliente = p_id_cliente;
    IF DATEDIFF(NOW(), v_fecha_registro) <= 30 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;


-- 7. fn_CalcularCostoEnvio O.O
CREATE FUNCTION fn_CalcularCostoEnvio(p_cantidad_articulos INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_costo_envio DECIMAL(10,2);
    SET v_costo_envio = 5.00 + (p_cantidad_articulos * 2.00);
    RETURN v_costo_envio;
END;


-- 8. fn_AplicarDescuento :D
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(10,2), p_porcentaje DECIMAL(5,2)) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN p_monto - (p_monto * (p_porcentaje / 100));
END;


-- 9. fn_ObtenerUltimaFechaCompra (─‿‿─)
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT) 
RETURNS DATETIME
READS SQL DATA
BEGIN
    DECLARE v_ultima_fecha DATETIME;
    SELECT MAX(ventas.fecha_venta) INTO v_ultima_fecha
    FROM ventas
    WHERE ventas.id_cliente = p_id_cliente AND ventas.estado != 'Cancelado';
    RETURN v_ultima_fecha;
END;


-- 10. fn_ValidarFormatoEmail
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150)) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    IF p_email LIKE '%@%.%' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;


-- 11. fn_ObtenerNombreCategoria :)
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT) 
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_nombre_categoria VARCHAR(100);
    SELECT categorias.nombre INTO v_nombre_categoria
    FROM productos
    INNER JOIN categorias ON productos.id_categoria = categorias.id_categoria
    WHERE productos.id_producto = p_id_producto;
    RETURN v_nombre_categoria;
END;


-- 12. fn_ContarVentasCliente
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total_compras INT;
    SELECT COUNT(ventas.id_venta) INTO v_total_compras
    FROM ventas
    WHERE ventas.id_cliente = p_id_cliente AND ventas.estado != 'Cancelado';
    RETURN v_total_compras;
END;


-- 13. fn_CalcularDiasDesdeUltimaCompra (╥﹏╥)
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_dias INT;
    DECLARE v_ultima_compra DATETIME;
    SET v_ultima_compra = fn_ObtenerUltimaFechaCompra(p_id_cliente);
    IF v_ultima_compra IS NULL THEN
        RETURN -1;
    END IF;
    SET v_dias = DATEDIFF(NOW(), v_ultima_compra);
    RETURN v_dias;
END;


-- 14. fn_DeterminarEstadoLealtad
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_total_gastado DECIMAL(12,2)) 
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    IF p_total_gastado >= 5000.00 THEN
        RETURN 'Oro';
    ELSEIF p_total_gastado >= 1000.00 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END;


-- 15. fn_GenerarSKU
CREATE FUNCTION fn_GenerarSKU(p_nombre_producto VARCHAR(150), p_nombre_categoria VARCHAR(100)) 
RETURNS VARCHAR(50)
NO SQL
BEGIN
    DECLARE v_sku VARCHAR(50);
    SET v_sku = UPPER(CONCAT(
        SUBSTRING(p_nombre_categoria, 1, 3), '-', 
        SUBSTRING(REPLACE(p_nombre_producto, ' ', ''), 1, 4), '-',
        FLOOR(RAND() * 9000 + 1000)
    ));
    RETURN v_sku;
END;


-- 16. fn_CalcularIVA (-_-)
CREATE FUNCTION fn_CalcularIVA(p_monto_total DECIMAL(10,2)) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN p_monto_total * 0.19;
END;


-- 17. fn_ObtenerStockTotalPorCategoria
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock_total INT;
    SELECT IFNULL(SUM(productos.stock), 0) INTO v_stock_total
    FROM productos
    WHERE productos.id_categoria = p_id_categoria;
    RETURN v_stock_total;
END;


-- 18. fn_EstimarFechaEntrega
CREATE FUNCTION fn_EstimarFechaEntrega(p_direccion VARCHAR(255)) 
RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE v_fecha_estimada DATE;
    IF p_direccion LIKE '%Bogotá%' THEN
        SET v_fecha_estimada = DATE_ADD(CURDATE(), INTERVAL 2 DAY);
    ELSE
        SET v_fecha_estimada = DATE_ADD(CURDATE(), INTERVAL 5 DAY);
    END IF;
    RETURN v_fecha_estimada;
END;


-- 19. fn_ConvertirMoneda
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(10,2), p_tasa_cambio DECIMAL(10,4)) 
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN p_monto * p_tasa_cambio;
END;


-- 20. fn_ValidarComplejidadContrasenia
CREATE FUNCTION fn_ValidarComplejidadContrasenia(p_contrasenia VARCHAR(255)) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    IF LENGTH(p_contrasenia) >= 8 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;

-- PRUEBAS PARA SABER SI FUNCIONAN.

-- 1. fn_CalcularTotalVenta (っ◕‿◕)っ
SELECT fn_CalcularTotalVenta(1);

-- 2. fn_VerificarDisponibilidadStock (._.)
SELECT fn_VerificarDisponibilidadStock(1, 5);

-- 3. fn_ObtenerPrecioProducto ◕‿◕
SELECT fn_ObtenerPrecioProducto(1);

-- 4. fn_CalcularEdadCliente
SELECT fn_CalcularEdadCliente('1995-06-15');

-- 5. fn_FormatearNombreCompleto :D
SELECT fn_FormatearNombreCompleto('Daniel', 'Tomas');

-- 6. fn_EsClienteNuevo
SELECT fn_EsClienteNuevo(1);

-- 7. fn_CalcularCostoEnvio O.O
SELECT fn_CalcularCostoEnvio(3);

-- 8. fn_AplicarDescuento :D
SELECT fn_AplicarDescuento(100.00, 20.00);

-- 9. fn_ObtenerUltimaFechaCompra (─‿‿─)
SELECT fn_ObtenerUltimaFechaCompra(1);

-- 10. fn_ValidarFormatoEmail
SELECT fn_ValidarFormatoEmail('tomasjk@mail.com');

-- 11. fn_ObtenerNombreCategoria :)
SELECT fn_ObtenerNombreCategoria(1);

-- 12. fn_ContarVentasCliente
SELECT fn_ContarVentasCliente(1);

-- 13. fn_CalcularDiasDesdeUltimaCompra (╥﹏╥)
SELECT fn_CalcularDiasDesdeUltimaCompra(1);

-- 14. fn_DeterminarEstadoLealtad
SELECT fn_DeterminarEstadoLealtad(2500.00);

-- 15. fn_GenerarSKU
SELECT fn_GenerarSKU('Monitor Pro', 'Electronica');

-- 16. fn_CalcularIVA (-_-)
SELECT fn_CalcularIVA(250.00);

-- 17. fn_ObtenerStockTotalPorCategoria
SELECT fn_ObtenerStockTotalPorCategoria(1);

-- 18. fn_EstimarFechaEntrega
SELECT fn_EstimarFechaEntrega('Calle 1, Bogotá');

-- 19. fn_ConvertirMoneda
SELECT fn_ConvertirMoneda(100.00, 4200.0000);

-- 20. fn_ValidarComplejidadContrasenia O.O
SELECT fn_ValidarComplejidadContrasenia('Segura123!');