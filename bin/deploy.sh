# 環境変数の設定を確認
export TF_VAR_aws_access_key="AKIAXXXXXXXXXXXXXXXXXX"
export TF_VAR_aws_secret_key="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export ENV="dev"
export CLOUD="gc"
export COMPONENTS="common"
export WORK_DIR="components/${CLOUD}/${COMPONENTS}"
echo $TF_VAR_aws_access_key
echo $TF_VAR_aws_secret_key
echo $ENV
echo $CLOUD
echo $COMPONENTS
echo $WORK_DIR
cd $WORK_DIR

# workspaceは利用しない
# terraform workspace select [ default / product / staging / develop ]

# 初期化　このタイミングでbackendのprefixを環境に対応するもので更新する
terraform init --backend-config=prefix=${ENV}/${COMPONENTS_DIR} -migrate-state

# Dry run
terraform plan \
-var-file="../../../environments/terraform.tfvars" \
-var-file="../../../environments/${ENV}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/${COMPONENTS}/terraform.tfvars"
