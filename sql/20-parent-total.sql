SELECT count(*) AS bks,
       round(sum(channel_price_cny)) AS ttv_cny,
       count(DISTINCT parent_client_id) AS parents
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf
WHERE supplier_id = {supplier_id}
  AND channel_create_date >= '{start}'
  AND channel_create_date < '{end}'
  AND channel_status_code IN (2, 3)
  AND client_group_id = 3
  AND supplier_rebook_sequence = 1
