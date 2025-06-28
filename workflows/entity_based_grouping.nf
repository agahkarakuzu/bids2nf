import org.yaml.snakeyaml.Yaml
include { LIBBIDS_SH_PARSE } from '../modules/lib_bids_sh_parser.nf'


workflow ENTITY_BASED_GROUPING {
  take:
  bids_dir
  bids2nf_config

  main:
  parsed_csv = LIBBIDS_SH_PARSE(bids_dir, params.libbids_sh)
  
  def config = new Yaml().load(new FileReader(bids2nf_config))

  input_files = parsed_csv
    .splitCsv(header: true)
    .filter { row -> config.containsKey(row.suffix) }
    .map { row -> 
      def suffix_config = config[row.suffix]
      
      def group_name = ''
      if (!suffix_config.containsKey('entity_based_grouping')) return null
      suffix_config.entity_based_grouping.each { grouping_name, grouping_config ->
        def matches = true
        grouping_config.each { entity, value ->
          if (entity != 'description' && row[entity] != value) {
            matches = false
          }
        }
        if (matches) {
          group_name = grouping_name
        }
      }
      
      tuple([row.subject, row.session, row.run, row.suffix, group_name, row.extension], "${row.path}")
    }
    .filter { subject_session_run_suffix_group_ext, file_path -> 
      subject_session_run_suffix_group_ext[4] != ''
    }

    input_pairs = input_files
    .map { subject_session_run_suffix_group_ext, file_path ->
      def (subject, session, run, suffix, group_name, extension) = subject_session_run_suffix_group_ext
      tuple([subject, session, run, suffix, group_name], [extension, file_path])
    }
    .groupTuple()
    .map { subject_session_run_suffix_group, ext_files ->
      def (subject, session, run, suffix, group_name) = subject_session_run_suffix_group
      
      def file_map = [:]
      ext_files.each { extension, file_path ->
        file_map[extension] = file_path
      }
      
      def has_nii = file_map.containsKey('nii') || file_map.containsKey('nii.gz')
      def has_json = file_map.containsKey('json')
      
      if (has_nii && has_json) {
        def nii_file = file_map.containsKey('nii.gz') ? file_map['nii.gz'] : file_map['nii']
        def json_file = file_map['json']
        tuple([subject, session, run, suffix, group_name], [nii_file, json_file])
      } else {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${group_name}: Missing required extensions. Available: ${file_map.keySet()}, Required: nii/nii.gz and json"
        null
      }
    }
    .filter { it != null }

  final_groups = input_pairs
    .map { subject_session_run_suffix_group, nii_json_pair ->
      def (subject, session, run, suffix, group_name) = subject_session_run_suffix_group
      def (nii_file, json_file) = nii_json_pair
      
      // Create flexible grouping key that includes available entities
      def grouping_key = [subject]
      if (session && session != "NA") {
        grouping_key << session
      }
      if (run && run != "NA") {
        grouping_key << run
      }
      
      tuple(grouping_key, [suffix, group_name, nii_file, json_file])
    }
    .groupTuple()
    .map { grouping_key, suffix_grouping_files ->
      def subject = grouping_key[0]
      def session = grouping_key.size() > 1 ? grouping_key[1] : "NA"
      def run = grouping_key.size() > 2 ? grouping_key[2] : "NA"
      
      def all_grouping_maps = [:]
      def all_file_paths = []
      
      suffix_grouping_files.each { suffix, group_name, nii_file, json_file ->
        if (!all_grouping_maps.containsKey(suffix)) {
          all_grouping_maps[suffix] = [:]
        }
        all_grouping_maps[suffix][group_name] = [
          'nii': nii_file,
          'json': json_file
        ]
        all_file_paths << nii_file
        all_file_paths << json_file
      }

      def all_complete = true
      all_grouping_maps.each { suffix, grouping_map ->
        def suffix_config = config[suffix]
        def has_all_groupings = suffix_config.required.every { required_grouping ->
          grouping_map.containsKey(required_grouping)
        }
        if (!has_all_groupings) {
          log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required groupings. Available: ${grouping_map.keySet()}, Required: ${suffix_config.required}"
          all_complete = false
        }
      }
      
      if (all_complete) {
        tuple(grouping_key, [all_grouping_maps, all_file_paths])
      } else {
        null
      }
    }
    .filter { it != null }

  emit:
  final_groups
}