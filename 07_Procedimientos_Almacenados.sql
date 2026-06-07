-- ARCHIVO: 07_Procedimientos_Almacenados.sql
USE ecommerce_db;

-- Tabla que sp_AjustarNivelStock necesita
CREATE TABLE IF NOT EXISTS log_cambios_usuario (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(255),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    ejecutado_por VARCHAR(100)
);

-- Tabla que sp_AñadirReseñaProducto necesita
CREATE TABLE IF NOT EXISTS resenas_productos (
    id_resena INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    calificacion TINYINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario TEXT,
    fecha_resena DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);


-- 1. sp_RealizarNuevaVenta
-- Procesa una venta de forma transaccional: encabezado, detalle y descuento de stock (っ◕‿◕)っ
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_id_venta_creada INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_precio DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error: la transacción fue revertida.';
        SET p_id_venta_creada = -1;
    END;

    START TRANSACTION;

    SELECT stock, precio INTO v_stock, v_precio
    FROM productos WHERE id_producto = p_id_producto FOR UPDATE;

    IF v_stock < p_cantidad THEN
        ROLLBACK;
        SET p_mensaje = 'Stock insuficiente para procesar la venta.';
        SET p_id_venta_creada = -1;
    ELSE
        INSERT INTO ventas (id_cliente, estado, total)
        VALUES (p_id_cliente, 'Procesando', 0.00);
        SET p_id_venta_creada = LAST_INSERT_ID();

        INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
        VALUES (p_id_venta_creada, p_id_producto, p_cantidad, v_precio);

        UPDATE ventas SET total = v_precio * p_cantidad WHERE id_venta = p_id_venta_creada;
        UPDATE productos SET stock = stock - p_cantidad WHERE id_producto = p_id_producto;

        COMMIT;
        SET p_mensaje = 'Venta registrada con éxito.';
    END IF;
END;


-- 2. sp_AgregarNuevoProducto
-- Inserta un producto validando SKU único y precio positivo (._.)
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_id_categoria INT,
    IN p_id_proveedor INT,
    IN p_nombre VARCHAR(150),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2),
    IN p_stock INT,
    IN p_sku VARCHAR(50),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF EXISTS (SELECT 1 FROM productos WHERE sku = p_sku) THEN
        SET p_mensaje = 'Error: el SKU ya existe en el sistema.';
    ELSEIF p_precio <= 0 THEN
        SET p_mensaje = 'Error: el precio debe ser mayor que cero.';
    ELSE
        INSERT INTO productos (id_categoria, id_proveedor, nombre, descripcion, precio, costo, stock, sku)
        VALUES (p_id_categoria, p_id_proveedor, p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku);
        SET p_mensaje = CONCAT('Producto "', p_nombre, '" creado con éxito.');
    END IF;
END;


-- 3. sp_ActualizarDireccionCliente
-- Actualiza la dirección de envío buscando al cliente por email ◕‿◕
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_email VARCHAR(150),
    IN p_nueva_direccion TEXT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    SELECT id_cliente INTO v_id FROM clientes WHERE email = p_email LIMIT 1;

    IF v_id IS NULL THEN
        SET p_mensaje = 'Error: no se encontró el cliente con ese email.';
    ELSE
        UPDATE clientes SET direccion_envio = p_nueva_direccion WHERE id_cliente = v_id;
        SET p_mensaje = 'Dirección actualizada correctamente.';
    END IF;
END;


-- 4. sp_ProcesarDevolucion
-- Cancela una venta y restaura el stock de sus productos :D
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error inesperado al procesar la devolución.';
    END;

    SELECT estado INTO v_estado FROM ventas WHERE id_venta = p_id_venta LIMIT 1;

    IF v_estado IS NULL THEN
        SET p_mensaje = 'Error: la venta no existe.';
    ELSEIF v_estado = 'Cancelado' THEN
        SET p_mensaje = 'Esa venta ya está cancelada, no se puede devolver.';
    ELSE
        START TRANSACTION;

        UPDATE ventas SET estado = 'Cancelado' WHERE id_venta = p_id_venta;

        UPDATE productos p
        INNER JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
        SET p.stock = p.stock + dv.cantidad
        WHERE dv.id_venta = p_id_venta;

        COMMIT;
        SET p_mensaje = 'Devolución procesada y stock restaurado.';
    END IF;
END;


-- 5. sp_ObtenerHistorialComprasCliente
-- Historial completo de compras de un cliente con sus detalles (─‿‿─)
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT
)
BEGIN
    SELECT 
        v.id_venta,
        v.fecha_venta,
        v.estado,
        v.total,
        p.nombre AS producto,
        dv.cantidad,
        dv.precio_unitario_congelado
    FROM ventas v
    INNER JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    INNER JOIN productos p ON dv.id_producto = p.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END;


-- 6. sp_AjustarNivelStock
-- Ajuste manual de stock registrando el motivo (╥﹏╥)
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_nuevo_stock INT,
    IN p_motivo VARCHAR(255),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF p_nuevo_stock < 0 THEN
        SET p_mensaje = 'Error: el stock no puede ser negativo.';
    ELSEIF NOT EXISTS (SELECT 1 FROM productos WHERE id_producto = p_id_producto) THEN
        SET p_mensaje = 'Error: el producto no existe.';
    ELSE
        UPDATE productos SET stock = p_nuevo_stock WHERE id_producto = p_id_producto;
        INSERT INTO log_cambios_usuario (descripcion, ejecutado_por)
        VALUES (CONCAT('Ajuste de stock producto #', p_id_producto, ': ', p_motivo), USER());
        SET p_mensaje = 'Stock ajustado correctamente.';
    END IF;
END;


-- 7. sp_EliminarClienteDeFormaSegura
-- Anonimiza datos del cliente sin romper integridad referencial O.O
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente) THEN
        SET p_mensaje = 'Error: el cliente no existe.';
    ELSE
        UPDATE clientes
        SET 
            nombre        = 'ANONIMO',
            apellido      = 'ELIMINADO',
            email         = CONCAT('eliminado_', p_id_cliente, '@noreply.com'),
            contrasenia   = 'REDACTED',
            direccion_envio = NULL
        WHERE id_cliente = p_id_cliente;
        SET p_mensaje = 'Cliente anonimizado correctamente.';
    END IF;
END;


-- 8. sp_AplicarDescuentoPorCategoria
-- Aplica un porcentaje de descuento a todos los productos activos de una categoría :)
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje DECIMAL(5,2),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF p_porcentaje <= 0 OR p_porcentaje >= 100 THEN
        SET p_mensaje = 'Error: el porcentaje debe estar entre 0 y 100.';
    ELSE
        UPDATE productos
        SET precio = ROUND(precio - (precio * p_porcentaje / 100), 2)
        WHERE id_categoria = p_id_categoria AND activo = TRUE;
        SET p_mensaje = CONCAT('Descuento de ', p_porcentaje, '% aplicado a la categoría.');
    END IF;
END;


-- 9. sp_GenerarReporteMensualVentas
-- Resumen de ventas para un mes y año específicos ◕‿◕
CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    SELECT 
        COUNT(v.id_venta)                                                AS total_pedidos,
        IFNULL(SUM(v.total), 0)                                          AS ingresos_totales,
        IFNULL(AVG(v.total), 0)                                          AS ticket_promedio,
        COUNT(DISTINCT v.id_cliente)                                     AS clientes_distintos,
        SUM(CASE WHEN v.estado = 'Cancelado' THEN 1 ELSE 0 END)         AS pedidos_cancelados
    FROM ventas v
    WHERE YEAR(v.fecha_venta) = p_anio AND MONTH(v.fecha_venta) = p_mes;
END;


-- 10. sp_CambiarEstadoPedido
-- Cambia el estado de un pedido con validaciones lógicas (._.)
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(50),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50) DEFAULT NULL;

    SELECT estado INTO v_estado_actual FROM ventas WHERE id_venta = p_id_venta LIMIT 1;

    IF v_estado_actual IS NULL THEN
        SET p_mensaje = 'Error: el pedido no existe.';
    ELSEIF v_estado_actual = 'Cancelado' THEN
        SET p_mensaje = 'Error: no se puede cambiar el estado de un pedido cancelado.';
    ELSEIF v_estado_actual = 'Entregado' THEN
        SET p_mensaje = 'Error: el pedido ya fue entregado.';
    ELSE
        UPDATE ventas SET estado = p_nuevo_estado WHERE id_venta = p_id_venta;
        SET p_mensaje = CONCAT('Estado actualizado a: ', p_nuevo_estado);
    END IF;
END;


-- 11. sp_RegistrarNuevoCliente
-- Registra un cliente validando email único y formato :D
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_contrasenia VARCHAR(255),
    IN p_direccion TEXT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF p_email NOT LIKE '%@%.%' THEN
        SET p_mensaje = 'Error: el formato del email no es válido.';
    ELSEIF EXISTS (SELECT 1 FROM clientes WHERE email = p_email) THEN
        SET p_mensaje = 'Error: el email ya está registrado en el sistema.';
    ELSE
        INSERT INTO clientes (nombre, apellido, email, contrasenia, direccion_envio)
        VALUES (p_nombre, p_apellido, p_email, p_contrasenia, p_direccion);
        SET p_mensaje = CONCAT('Cliente ', p_nombre, ' registrado con éxito.');
    END IF;
END;


-- 12. sp_ObtenerDetallesProductoCompleto
-- Info completa de un producto: categoría, proveedor, margen (─‿‿─)
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre                                                                    AS producto,
        p.descripcion,
        p.precio,
        p.costo,
        ROUND(((p.precio - p.costo) / NULLIF(p.precio, 0)) * 100, 2)              AS margen_porcentaje,
        p.stock,
        p.sku,
        p.activo,
        c.nombre                                                                    AS categoria,
        prov.nombre                                                                 AS proveedor,
        prov.email_contacto                                                         AS contacto_proveedor
    FROM productos p
    INNER JOIN categorias c    ON p.id_categoria  = c.id_categoria
    INNER JOIN proveedores prov ON p.id_proveedor = prov.id_proveedor
    WHERE p.id_producto = p_id_producto;
END;


-- 13. sp_FusionarCuentasCliente
-- Mueve ventas de cuenta duplicada a la principal y anonimiza la duplicada O.O
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT,
    IN p_id_cliente_duplicado INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_msg_interno VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error al fusionar las cuentas.';
    END;

    IF p_id_cliente_principal = p_id_cliente_duplicado THEN
        SET p_mensaje = 'Error: los IDs de cliente son iguales.';
    ELSEIF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente_principal) THEN
        SET p_mensaje = 'Error: el cliente principal no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente_duplicado) THEN
        SET p_mensaje = 'Error: el cliente duplicado no existe.';
    ELSE
        START TRANSACTION;

        UPDATE ventas
        SET id_cliente = p_id_cliente_principal
        WHERE id_cliente = p_id_cliente_duplicado;

        UPDATE clientes
        SET total_gastado = (
            SELECT IFNULL(SUM(total), 0)
            FROM ventas
            WHERE id_cliente = p_id_cliente_principal
            AND estado = 'Entregado'
        )
        WHERE id_cliente = p_id_cliente_principal;

        COMMIT;

        -- La anonimización va fuera de la transacción para evitar conflicto con el EXIT HANDLER
        CALL sp_EliminarClienteDeFormaSegura(p_id_cliente_duplicado, v_msg_interno);
        SET p_mensaje = CONCAT('Cuentas fusionadas. Cuenta #', p_id_cliente_duplicado, ' anonimizada.');
    END IF;
END;


-- 14. sp_AsignarProductoAProveedor
-- Cambia el proveedor de un producto con validaciones :)
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT,
    IN p_id_nuevo_proveedor INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos WHERE id_producto = p_id_producto) THEN
        SET p_mensaje = 'Error: el producto no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = p_id_nuevo_proveedor) THEN
        SET p_mensaje = 'Error: el proveedor no existe.';
    ELSE
        UPDATE productos SET id_proveedor = p_id_nuevo_proveedor WHERE id_producto = p_id_producto;
        SET p_mensaje = 'Proveedor actualizado correctamente.';
    END IF;
END;


-- 15. sp_BuscarProductos
-- Búsqueda avanzada con filtros opcionales por nombre, categoría y precio (╥﹏╥)
CREATE PROCEDURE sp_BuscarProductos(
    IN p_nombre VARCHAR(150),
    IN p_id_categoria INT,
    IN p_precio_min DECIMAL(10,2),
    IN p_precio_max DECIMAL(10,2)
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.precio,
        p.stock,
        c.nombre AS categoria
    FROM productos p
    INNER JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE p.activo = TRUE
        AND (p_nombre       IS NULL OR p.nombre       LIKE CONCAT('%', p_nombre, '%'))
        AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
        AND (p_precio_min   IS NULL OR p.precio       >= p_precio_min)
        AND (p_precio_max   IS NULL OR p.precio       <= p_precio_max)
    ORDER BY p.nombre ASC;
END;


-- 16. sp_ObtenerDashboardAdmin
-- KPIs del día actual para el panel de administración (っ◕‿◕)っ
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT
        (SELECT COUNT(*)           FROM ventas   WHERE DATE(fecha_venta) = CURDATE())                                   AS ventas_hoy,
        (SELECT IFNULL(SUM(total), 0) FROM ventas WHERE DATE(fecha_venta) = CURDATE() AND estado != 'Cancelado')        AS ingresos_hoy,
        (SELECT COUNT(*)           FROM clientes WHERE DATE(fecha_registro) = CURDATE())                                AS nuevos_clientes_hoy,
        (SELECT COUNT(*)           FROM productos WHERE stock < 15 AND activo = TRUE)                                   AS productos_bajo_stock,
        (SELECT COUNT(*)           FROM ventas   WHERE estado = 'Pendiente de Pago'
                                                   AND fecha_venta < DATE_SUB(NOW(), INTERVAL 24 HOUR))                AS carritos_abandonados;
END;


-- 17. sp_ProcesarPago
-- Simula el pago de una venta y la pasa a estado Procesando (._.)
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    SELECT estado INTO v_estado FROM ventas WHERE id_venta = p_id_venta LIMIT 1;

    IF v_estado IS NULL THEN
        SET p_mensaje = 'Error: la venta no existe.';
    ELSEIF v_estado != 'Pendiente de Pago' THEN
        SET p_mensaje = CONCAT('Error: el estado actual es "', v_estado, '", no se puede pagar.');
    ELSE
        UPDATE ventas SET estado = 'Procesando' WHERE id_venta = p_id_venta;
        SET p_mensaje = 'Pago procesado. Venta en estado Procesando.';
    END IF;
END;


-- 18. sp_AnadirResenaProducto
-- Permite al cliente reseñar un producto que haya comprado y recibido ◕‿◕
CREATE PROCEDURE sp_AnadirResenaProducto(
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_compro INT DEFAULT 0;

    SELECT COUNT(*) INTO v_compro
    FROM ventas v
    INNER JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    WHERE v.id_cliente  = p_id_cliente
    AND dv.id_producto  = p_id_producto
    AND v.estado        = 'Entregado';

    IF v_compro = 0 THEN
        SET p_mensaje = 'Error: solo puedes reseñar productos que hayas comprado y recibido.';
    ELSEIF p_calificacion < 1 OR p_calificacion > 5 THEN
        SET p_mensaje = 'Error: la calificación debe estar entre 1 y 5.';
    ELSE
        INSERT INTO resenas_productos (id_cliente, id_producto, calificacion, comentario)
        VALUES (p_id_cliente, p_id_producto, p_calificacion, p_comentario);
        SET p_mensaje = 'Reseña publicada correctamente.';
    END IF;
END;


-- 19. sp_ObtenerProductosRelacionados
-- Productos que otros clientes compraron junto al producto dado (─‿‿─)
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.precio,
        COUNT(*) AS veces_comprado_junto
    FROM detalle_ventas dv1
    INNER JOIN detalle_ventas dv2
        ON  dv1.id_venta    = dv2.id_venta
        AND dv2.id_producto != p_id_producto
    INNER JOIN productos p ON dv2.id_producto = p.id_producto
    WHERE dv1.id_producto = p_id_producto
    AND   p.activo        = TRUE
    GROUP BY p.id_producto, p.nombre, p.precio
    ORDER BY veces_comprado_junto DESC
    LIMIT 5;
END;


-- 20. sp_MoverProductosEntreCategorias
-- Mueve todos los productos de una categoría a otra de forma segura O.O
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT,
    IN p_id_categoria_destino INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_productos_afectados INT DEFAULT 0;

    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria_origen) THEN
        SET p_mensaje = 'Error: la categoría origen no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria_destino) THEN
        SET p_mensaje = 'Error: la categoría destino no existe.';
    ELSEIF p_id_categoria_origen = p_id_categoria_destino THEN
        SET p_mensaje = 'Error: origen y destino no pueden ser la misma categoría.';
    ELSE
        SELECT COUNT(*) INTO v_productos_afectados
        FROM productos WHERE id_categoria = p_id_categoria_origen;

        UPDATE productos
        SET id_categoria = p_id_categoria_destino
        WHERE id_categoria = p_id_categoria_origen;

        SET p_mensaje = CONCAT(v_productos_afectados, ' producto(s) movidos correctamente.');
    END IF;
END;