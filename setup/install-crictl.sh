#!/bin/bash

# Definir URL base do GitHub Releases
GITHUB_URL="https://github.com/kubernetes-sigs/cri-tools/releases/latest"

# Obter a última versão disponível
LATEST_VERSION=$(curl -sL -o /dev/null -w %{url_effective} $GITHUB_URL | grep -oP 'v\d+\.\d+\.\d+')

# Verificar se a versão foi encontrada
if [[ -z "$LATEST_VERSION" ]]; then
    echo "❌ Não foi possível obter a última versão do crictl."
    exit 1
fi

echo "🔹 Última versão encontrada: $LATEST_VERSION"

# Definir URL do binário
CRICTL_TAR="crictl-$LATEST_VERSION-linux-amd64.tar.gz"
CRICTL_URL="https://github.com/kubernetes-sigs/cri-tools/releases/download/$LATEST_VERSION/$CRICTL_TAR"

echo "📥 Baixando crictl de $CRICTL_URL..."
curl -LO $CRICTL_URL

# Verificar se o download foi bem-sucedido
if [[ ! -f "$CRICTL_TAR" ]]; then
    echo "❌ Falha ao baixar o crictl."
    exit 1
fi

echo "📦 Extraindo arquivos..."
tar -xzf $CRICTL_TAR

echo "🚀 Movendo para /usr/local/bin..."
sudo mv crictl /usr/local/bin/
sudo chmod +x /usr/local/bin/crictl

# Remover o arquivo tar
rm -f $CRICTL_TAR

echo "✅ crictl instalado com sucesso! Versão: $(crictl --version)"
