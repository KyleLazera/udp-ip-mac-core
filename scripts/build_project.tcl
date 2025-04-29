
set proj_name network_stack
set proj_dir [file normalize "../$proj_name"]
set part_name xc7a200tsbg484-1

create_project $proj_name $proj_dir -part $part_name

#Add Source files Here