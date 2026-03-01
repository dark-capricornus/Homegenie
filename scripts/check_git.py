import subprocess
with open('git_output.txt', 'w') as f:
    f.write('--- STAGED ---\n')
    try:
        staged = subprocess.check_output(['git', 'diff', '--cached', '--name-only']).decode('utf-8')
        f.write(staged)
    except Exception as e:
        f.write(str(e))
    
    f.write('\n--- UNTRACKED ---\n')
    try:
        untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard']).decode('utf-8')
        f.write(untracked)
    except Exception as e:
        f.write(str(e))
