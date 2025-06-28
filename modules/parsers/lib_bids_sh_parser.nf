process LIBBIDS_SH_PARSE {
  input:
  path bids_dir
  path libbids_sh

  output:
  path "parsed.csv"

  script:
  """
  source ${libbids_sh}
  csv_data=\$(libBIDSsh_parse_bids_to_csv "${bids_dir}")
  echo "\$csv_data" > parsed.csv
  """
}
