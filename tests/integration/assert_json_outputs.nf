include { COMPARE_JSON_FILES } from '../../modules/utils/json_assert'

workflow {
    
    main:

    expected_jsons_ch = Channel
        .fromPath("${params.expected_dir}/**/*.json")
        .map { file -> 
        def relativePath = file.toString().replaceFirst("^${params.expected_dir}/", "")
        tuple(relativePath, file)
        }

    new_jsons_ch = Channel
        .fromPath("${params.new_dir}/**/*.json") 
        .map { file ->
        def relativePath = file.toString().replaceFirst("^${params.new_dir}/", "")
        tuple(relativePath, file)
        }

    // Find matched pairs for comparison
    paired_jsons_ch = expected_jsons_ch
        .join(new_jsons_ch, by: 0)
        .map { relativePath, expectedFile, newFile ->
        tuple(relativePath, expectedFile, newFile)
        }

    COMPARE_JSON_FILES(paired_jsons_ch)
    COMPARE_JSON_FILES.out.result.view()
}