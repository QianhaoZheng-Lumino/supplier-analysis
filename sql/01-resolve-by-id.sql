SELECT supplier_id, sid, supplier_name, op
FROM public.ovs_supplier_info_v
WHERE supplier_id = {supplier_id}
LIMIT 5
