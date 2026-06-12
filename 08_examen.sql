USE ecommerce_db;

WITH metricas_base AS (
    SELECT
        c.id_cliente,
        CONCAT(c.nombre, ' ', c.apellido) AS nombre_completo,
        c.email,
        DATEDIFF(NOW(), MAX(v.fecha_venta)) AS recencia_dias,
        COUNT(DISTINCT v.id_venta) AS frecuencia_compras,
        ROUND(SUM(v.total), 2) AS valor_monetario

    FROM clientes AS c
        INNER JOIN ventas AS v ON c.id_cliente = v.id_cliente
    WHERE v.estado != 'Cancelado'
    GROUP BY c.id_cliente, c.nombre, c.apellido, c.email
),

--  Convertimos las métricas brutas en puntuaciones del 1 al 4
scores_rfm AS (
    SELECT
        id_cliente,
        nombre_completo,
        email,
        recencia_dias,
        frecuencia_compras,
        valor_monetario,

		-- ordenamos ASC porque menos dias desde la ultima compra
        -- es mejor. NTILE(4) crea 4 grupos: el 25% con menos dias recibe score 4,
        -- el 25% con mas dias recibe score 1.
        NTILE(4) OVER (ORDER BY recencia_dias ASC)     AS score_recencia,

        -- ordenamos DESC porque mas compras es mejor.
        -- El 25% que mas compro recibe score 4, el que menos compro recibe score 1.
        NTILE(4) OVER (ORDER BY frecuencia_compras DESC) AS score_frecuencia,

        -- ordenamos DESC porque mas gasto es mejor.
        -- El 25% que mas gasto recibe score 4, el que menos gasto recibe score 1.
        NTILE(4) OVER (ORDER BY valor_monetario DESC)  AS score_monetario

    FROM metricas_base
),

-- Combinamos los scores y asignamos el segmento de negocio
segmentos AS (
    SELECT
        id_cliente,
        nombre_completo,
        email,
        recencia_dias,
        frecuencia_compras,
        valor_monetario,
        score_recencia,
        score_frecuencia,
        score_monetario,
    
        (score_recencia + score_frecuencia + score_monetario) AS score_total,

        CASE
     
            WHEN score_recencia = 4 AND score_frecuencia = 4 AND score_monetario = 4
                THEN 'Campeón'

            WHEN score_frecuencia >= 3 AND score_monetario >= 3
                THEN 'Leal'

            WHEN score_recencia >= 3 AND score_frecuencia <= 2
                THEN 'Potencial'

            WHEN score_recencia <= 2 AND score_frecuencia >= 3 AND score_monetario >= 3
                THEN 'En Riesgo'

            WHEN score_recencia = 1 AND score_frecuencia = 1 AND score_monetario = 1
                THEN 'Perdido'

            ELSE 'En Desarrollo'
        END AS segmento

    FROM scores_rfm
)

-- Consulta Final, mostramos todos los datos del analisis ordenados
-- por score total descendente para ver los clientes que son mas importantes.
SELECT
    id_cliente,
    nombre_completo,
    email,

    -- Metricas brutas para que marketing entienda el contexto detras del segmento
    recencia_dias       AS dias_desde_ultima_compra,
    frecuencia_compras  AS total_ordenes,
    valor_monetario     AS gasto_total,

    -- Scores individuales para transparencia del modelo
    score_recencia,
    score_frecuencia,
    score_monetario,
    score_total,

    -- El segmento es lo que marketing usara para filtrar su lista de contactos
    segmento

FROM segmentos

-- Ordenamos por score total para ver los clientes mas valiosos al inicio
ORDER BY score_total DESC, valor_monetario DESC;




SELECT
    segmento,
    COUNT(*)                          AS total_clientes,
    ROUND(AVG(valor_monetario), 2)    AS gasto_promedio,
    ROUND(AVG(recencia_dias), 0)      AS recencia_promedio_dias,
    ROUND(AVG(frecuencia_compras), 1) AS frecuencia_promedio
FROM segmentos
GROUP BY segmento
ORDER BY gasto_promedio DESC;
