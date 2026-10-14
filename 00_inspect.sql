SELECT "Total", typeof("Total")
FROM read_csv_auto('Proyecto-BI-Colombia/compras_tvec.csv')
LIMIT 5;
DESCRIBE SELECT * FROM read_csv_auto('Proyecto-BI-Colombia/compras_tvec.csv');