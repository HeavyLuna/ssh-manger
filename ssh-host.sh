#!/bin/zsh

# 服务器信息文件路径
SERVERS_FILE="./servers.csv"

# 计算字符串的显示宽度，每个 Unicode 字符算作两个字符宽度
function display_width() {
    local str="$1"
    local chinese_chars=$(echo -n "$str" | perl -CS -ne 'print scalar(() = m/\p{Han}/g)')
    local total_chars=$(echo -n "$str" | wc -m)
    local non_chinese_chars=$((total_chars - chinese_chars))
    local width=$((chinese_chars * 2 + non_chinese_chars))
    echo $width
}

# 显示服务器列表并读取用户选择
echo "+------+-------------------------------+-------------------+"
echo "| 序号 | 名称                           | IP               |"
echo "+------+-------------------------------+-------------------+"
IFS=","
index=1
while read -r name ip port user password encryption; do
    name_width=$(display_width "$name")
    padding=$((30 - name_width))
    ip_width=$(display_width "$ip")
    ip_padding=$((16 - ip_width))
    printf "| %-4s | %s%*s | %s%*s |\n" "$index." "$name" "$padding" "" "$ip" "$ip_padding" ""
    server_names[index]=$name
    server_ips[index]=$ip
    server_ports[index]=$port
    server_users[index]=$user
    server_passwords[index]=$password
    server_encryptions[index]=$encryption
    ((index++))
    echo "+------+------------------------------+--------------------+"
done < "$SERVERS_FILE"
unset IFS
((index--))  # Reduce index by 1 after reading all servers

while true; do
    echo "请输入您的选择（数字或服务器名称/IP/端口号）："
    read choice

    # 如果输入是数字，且在服务器数量范围内，直接选择对应服务器
    if [[ $choice =~ ^[0-9]+$ && $choice -ge 1 && $choice -le $index ]]; then
        break
    fi

    # 尝试解析输入为服务器的 IP 或名称或端口号中的一部分
    match_indexes=()
    for ((i=1; i<=$index; i++)); do
        if [[ ${server_names[$i]} == *$choice* ||
              ${server_ips[$i]} == *$choice* ||
              (${server_ports[$i]+exists} && ${server_ports[$i]} == *$choice*) ]]; then
            match_indexes+=($i)
        fi
    done
    # 检查匹配结果
    if [[ ${#match_indexes[@]} -eq 0 ]]; then
        echo "无匹配结果。"
        continue
    elif [[ ${#match_indexes[@]} -eq 1 ]]; then
        choice=${match_indexes[@]}
        break
    else
        echo "找到多个匹配结果，请选择："
        local_index=1
        declare -A match_indexes_new
        for i in ${match_indexes[@]}; do
            name_width=$(display_width "${server_names[$i]}")
            padding=$((35 - name_width))
            printf "%-4s %s%*s %s\n" "$local_index." "${server_names[$i]}" "$padding" "" "${server_ips[$i]}"
            match_indexes_new[$local_index]=$i
            ((local_index++))
        done
        read choice
        if [[ -n ${match_indexes_new[$choice]} && $choice =~ ^[0-9]+$ ]]; then
            choice=${match_indexes_new[$choice]}
            break
        else
            echo "无效的选择。"
            continue
        fi
    fi
done

# 显示SSH命令和密码
echo "已选择服务器： ${server_names[$choice]} ..."
echo "SSH命令："
# 构造SSH命令
ssh_command="ssh ${server_users[$choice]}@${server_ips[$choice]}"

# 如果端口号非空，添加-p选项
if [[ -n ${server_ports[$choice]} ]]; then
    ssh_command="${ssh_command} -p ${server_ports[$choice]}"
fi

# 如果加密方式非空，添加-oHostKeyAlgorithms选项
if [[ -n ${server_encryptions[$choice]} ]]; then
    ssh_command="${ssh_command} -oHostKeyAlgorithms=${server_encryptions[$choice]}"
fi

echo -e "\033[32m${ssh_command}\033[0m"
# 将SSH命令复制到剪贴板，使用echo -n防止在末尾添加换行符
echo -n "${ssh_command}" | pbcopy
echo "密码："
echo -e "\033[31m${server_passwords[$choice]}\033[0m"
