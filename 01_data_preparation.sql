-- ============================================================
-- PROYECTO: Dashboard de Inteligencia de Clientes y Ventas (Colombia)
-- AUTOR: Amaury Muñiz
-- HERRAMIENTA: DuckDB 
-- ============================================================

-- 1. Crear la vista principal con limpia conversión de la columna Total
CREATE OR REPLACE VIEW vw_ventas_limpias AS
SELECT 
    CAST("Identificador de la Orden" AS VARCHAR) AS id_orden,
    "Fecha" AS fecha_venta,
    UPPER(TRIM(CAST("Ciudad" AS VARCHAR))) AS municipio,
    TRIM(CAST("Entidad" AS VARCHAR)) AS cliente,
    TRIM(CAST("Proveedor" AS VARCHAR)) AS proveedor,
    TRIM(CAST("Sector de la Entidad" AS VARCHAR)) AS categoria_producto,
    -- Limpieza de texto para convertir valores numéricos en formato colombiano o texto
    ROUND(
        COALESCE(
            TRY_CAST("Total" AS DOUBLE),
            TRY_CAST(REPLACE(REPLACE(CAST("Total" AS VARCHAR), '.', ''), ',', '.') AS DOUBLE),
            TRY_CAST(REGEXP_REPLACE(CAST("Total" AS VARCHAR), '[^0-9]', '', 'g') AS DOUBLE)
        ), 2
    ) AS venta_neto_cop
FROM read_csv_auto('Proyecto-BI-Colombia/compras_tvec.csv', ignore_errors=true)
WHERE "Fecha" IS NOT NULL;


-- 2. Crecimiento de Ventas Mes a Mes (MoM) usando Window Functions (LAG)
WITH VentasMensuales AS (
    SELECT 
        DATE_TRUNC('month', fecha_venta) AS mes,
        SUM(venta_neto_cop) AS total_ventas_cop,
        COUNT(DISTINCT id_orden) AS total_ordenes
    FROM vw_ventas_limpias
    WHERE fecha_venta IS NOT NULL AND venta_neto_cop > 0
    GROUP BY DATE_TRUNC('month', fecha_venta)
)
SELECT 
    mes,
    total_ventas_cop,
    LAG(total_ventas_cop, 1) OVER (ORDER BY mes) AS ventas_mes_anterior,
    ROUND(
        (total_ventas_cop - LAG(total_ventas_cop, 1) OVER (ORDER BY mes)) / 
        NULLIF(LAG(total_ventas_cop, 1) OVER (ORDER BY mes), 0) * 100, 2
    ) AS pct_crecimiento_mom
FROM VentasMensuales
ORDER BY mes DESC;


-- 3. Análisis de Recencia (Última compra por cliente usando ROW_NUMBER)
WITH RankingCompras AS (
    SELECT 
        cliente,
        municipio,
        fecha_venta,
        venta_neto_cop,
        ROW_NUMBER() OVER (PARTITION BY cliente ORDER BY fecha_venta DESC) AS rn
    FROM vw_ventas_limpias
    WHERE fecha_venta IS NOT NULL AND venta_neto_cop > 0
)
SELECT 
    cliente,
    municipio,
    fecha_venta AS fecha_ultima_compra,
    venta_neto_cop AS valor_ultima_compra
FROM RankingCompras
WHERE rn = 1;


-- 4. Exportar el conjunto limpio a un CSV optimizado para Power BI
COPY (
    SELECT * 
    FROM vw_ventas_limpias 
    WHERE fecha_venta IS NOT NULL AND venta_neto_cop IS NOT NULL AND venta_neto_cop > 0
) TO 'Proyecto-BI-Colombia/ventas_limpias_colombia.csv' (HEADER, DELIMITER ',');
