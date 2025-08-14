locals {
  repo_name = "${var.repo_name_prefix}-detection-rules"
}

data "external" "github_user" {
  program = ["bash", "-c", "gh api user --jq '{login:.login}' | jq -c ."]
}

resource "null_resource" "create_fork" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating fork of elastic/detection-rules as ${local.repo_name}..."
      
      GITHUB_USER="${data.external.github_user.result.login}"
      
      if gh repo view "$${GITHUB_USER}/${local.repo_name}" &>/dev/null; then
        echo "Repository ${local.repo_name} already exists"
      else
        echo "Forking elastic/detection-rules..."
        gh repo fork elastic/detection-rules --fork-name="${local.repo_name}" --clone=false
        echo "Fork created successfully as ${local.repo_name}"
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}

resource "null_resource" "clone_repository" {
  depends_on = [null_resource.create_fork]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      REPO_NAME="${local.repo_name}"
      TARGET_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${data.external.github_user.result.login}"
      
      if [ ! -d "$${TARGET_DIR}" ]; then
        echo "Waiting for fork to be available..."
        sleep 5
        
        echo "Cloning repository to $${TARGET_DIR}..."
        git clone "https://github.com/$${GITHUB_USER}/$${REPO_NAME}.git" "$${TARGET_DIR}"
        
        cd "$${TARGET_DIR}"
        
        echo "Adding upstream remote..."
        git remote add upstream "https://github.com/elastic/detection-rules.git"
        
        echo "Fetching upstream..."
        git fetch upstream
        
        echo "Setting upstream for main branch..."
        git branch --set-upstream-to=upstream/main main
        
        echo "Repository cloned and configured successfully!"
      else
        echo "Repository already exists at $${TARGET_DIR}"
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}