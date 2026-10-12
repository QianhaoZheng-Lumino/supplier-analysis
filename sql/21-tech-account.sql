SELECT t.supplieraccountid,
       a.account_name,
       t.avail_search_ss,
       t.total_search_ss,
       t.rp,
       t.issue_rp,
       t.failed_bks,
       t.bks
FROM data_ovs.supplier_analysis_tech_index_30d t
LEFT JOIN content.domain_supplier_account a
  ON a.account_id = t.supplieraccountid
WHERE t.supplierid = {supplier_id}
  AND (t.total_search_ss > 0 OR t.rp > 0 OR t.bks > 0)
ORDER BY t.total_search_ss DESC
LIMIT 200
