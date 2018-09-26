# Crontabeditassist

crontab edit assist is ONLY helpful when a system admin has disabled "Crond" Service with Un-commented crontab entries that will potentially run once the crond service is enabled.

To enabled Crond without running any of the crontab entries
this command line bash shell script identify and report
all Un-commented crontab and assist you in commenting ( adding Hash (#) in front of the line )

it takes a backup of the original file and creates overwrite files ( files with overwriting extension) to be modified and reviewed before replacing the original one


Using the references below, which is the core of this script, we have to build a four-step (process checks) around it 
1. take a backup of all original files and also another folder containing files with overwrite extension (i.e. ready for edit) 
2. Modify the tmp overwrite folder and once complete display the outcome for admin crosscheck 
3. (if comfortable then) Swap the overwrite files with the original ones
4. Used can choose which  folder (original, overwrite, backup) to display the uncommented crontabs from  

## References
https://stackoverflow.com/questions/134906/how-do-i-list-all-cron-jobs-for-all-users

https://gist.github.com/hanchang/1167330/a0b07afaf71a8a5dc1b55ca9d04349c1f8ca4437
