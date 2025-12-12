process libbids_sh_parse {
  input:
  path bids_dir
  path libbids_sh
  val libbids_config_dir

  output:
  path "parsed.csv"

  script:
  def config_arg = libbids_config_dir ? "\"${libbids_config_dir}\"" : ""
  """
  if [ -f "${libbids_sh}" ]; then
    source ${libbids_sh}
  elif [ -d "${libbids_sh}" ]; then
    source ${libbids_sh}/libBIDS.sh
  else
    echo "Error: libBIDS.sh path is neither a file nor a directory: ${libbids_sh}" >&2
    exit 1
  fi

  csv_data=\$(libBIDSsh_parse_bids_to_csv "${bids_dir}" ${config_arg})
  echo "\$csv_data" > parsed.csv
  """
}
