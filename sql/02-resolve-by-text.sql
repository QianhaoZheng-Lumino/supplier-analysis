SELECT supplier_id, sid, supplier_name, op
FROM public.ovs_supplier_info_v
WHERE supplier_name ILIKE '%' || '{q}' || '%'
   OR sid ILIKE '%' || '{q}' || '%'
   OR op = '{q}'
LIMIT 30
