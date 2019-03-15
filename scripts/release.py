import sys
import os
import subprocess
from github import Github
SEP = '-'
BUILD_DIR="build"

token = sys.argv[1]
repo_name = sys.argv[2]
tag = sys.argv[3]

# split off first part of tag
tag_parts = tag.split(SEP)
workflow_name = SEP.join(tag_parts[:-1])
workflow_path = 'workflows/{}.cwl'.format(workflow_name)
workflow_filename = os.path.basename(workflow_path)
packed_workflow_path = '{}/{}'.format(BUILD_DIR, workflow_filename)
version_str = tag_parts[-1]

if not os.path.exists(workflow_path):
    raise ValueError("No such workflow file found: {}.".format(workflow_path))

g = Github(token)
repo = g.get_repo(repo_name)
release = repo.get_release(tag)

release_assets = release.get_assets()
asset_names = [asset.name for asset in release_assets]
if workflow_filename in asset_names:
    raise ValueError("Packed workflow already exists in this release.")

os.makedirs(BUILD_DIR, exist_ok=True)
# pack the workflow
with open(packed_workflow_path, 'w') as outfile:
    subprocess.call(["cwltool", "--pack", workflow_path], stdout=outfile)
release.upload_asset(packed_workflow_path)
