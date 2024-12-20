# standardSQL
# rdfa_vocabs.sql
# Count RDFa Vocabs
CREATE TEMP FUNCTION getRDFaVocabs(rendered STRING)
RETURNS ARRAY<STRING>
LANGUAGE js AS """
  try {
    rendered = JSON.parse(rendered);
    return rendered.rdfa_vocabs.map(vocab => vocab.toLowerCase());
  } catch (e) {
    return [];
  }
""";

WITH
rendered_data AS (
  SELECT
    client,
    root_page AS url,
    getRDFaVocabs(JSON_EXTRACT(JSON_VALUE(JSON_EXTRACT(payload, '$._structured-data')), '$.structured_data.rendered')) AS rdfa_vocabs
  FROM
    `httparchive.all.pages`
  WHERE
    date = '2024-06-01'
),

page_totals AS (
  SELECT
    client,
    COUNT(DISTINCT root_page) AS total_pages
  FROM
    `httparchive.all.pages`
  WHERE
    date = '2024-06-01'
  GROUP BY
    client
)

SELECT
  client,
  rdfa_vocab,
  COUNT(rdfa_vocab) AS freq_rdfa_vocab,
  SUM(COUNT(rdfa_vocab)) OVER (PARTITION BY client) AS total_rdfa_vocab,
  COUNT(rdfa_vocab) / SUM(COUNT(rdfa_vocab)) OVER (PARTITION BY client) AS pct_rdfa_vocab,
  COUNT(DISTINCT url) AS freq_pages,
  total_pages,
  COUNT(DISTINCT url) / total_pages AS pct_pages
FROM (
  SELECT
    client,
    url,
    -- Removes the protocol and any subdomains from the URL.
    -- e.g. "https://my.example.com/pathname" becomes "example.com/pathname"
    -- This is done to normalize the URL a bit before counting.
    CONCAT(NET.REG_DOMAIN(rdfa_vocab), SPLIT(rdfa_vocab, NET.REG_DOMAIN(rdfa_vocab))[SAFE_OFFSET(1)]) AS rdfa_vocab
  FROM
    rendered_data,
    UNNEST(rdfa_vocabs) AS rdfa_vocab
)
JOIN
  page_totals
USING (client)
GROUP BY
  client,
  rdfa_vocab,
  total_pages
ORDER BY
  pct_pages DESC,
  client
