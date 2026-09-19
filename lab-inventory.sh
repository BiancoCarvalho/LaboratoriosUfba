# Inventory Script
# v0.0.1
# (add version to trigger update in 'lab-startup' cmp)

inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
inventory_url='https://inventario.app.ic.ufba.br/inventory'

###### Instalação do script de inventário ######
wget -O inventory.zip https://github.com/valdineifer/inventory_script/archive/refs/heads/master.zip
unzip -o inventory.zip -d /etc/gdm3/PostLogin
rm -rf inventory.zip

pip install -r "$inventory_path/src/requirements.txt"

python3 $inventory_path/src/inventory.py $inventory_url &> /var/log/inventory.log