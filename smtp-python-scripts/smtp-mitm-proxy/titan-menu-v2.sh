#!/bin/bash

HOST="127.0.0.1"
PORT="9999"

while true; do
    clear
    echo "==========================================="
    echo "      TITAN CONTROL MENU for Version 16.0"
    echo "==========================================="
    echo "Target: http://$HOST:$PORT"
    echo
    echo "GET endpoints:"
    echo "  1) /statustable"
    echo "  2) /rulesallowtable"
    echo "  3) /rulesblockedtable"
    echo "  4) /stats"
    echo "  5) /autoblockedtable"
    echo
    echo "POST endpoints:"
    echo "  6) /disconnect?ip=X"
    echo "  7) /disconnect_oldest?ip=X or ID=X"
    echo "  8) /disconnect_id?ID=X   (supports comma-separated IDs)"
    echo "  9) /hexdump/on"
    echo " 10) /hexdump/off"
    echo " 11) /disconnect_upstream?ID=X"
    echo
    echo "  0) Exit"
    echo
    read -p "Select option: " opt

    case "$opt" in
        1)
            curl -s "http://$HOST:$PORT/statustable"
            ;;
        2)
            curl -s "http://$HOST:$PORT/rulesallowtable"
            ;;
        3)
            curl -s "http://$HOST:$PORT/rulesblockedtable"
            ;;
        4)
            curl -s "http://$HOST:$PORT/stats" | jq
            ;;
        5)
            curl -s "http://$HOST:$PORT/autoblockedtable"
            ;;
        6)
            read -p "Enter IP (or q to abort): " ip
            [[ "$ip" == "q" || "$ip" == "Q" ]] && continue
            curl -s -X POST "http://$HOST:$PORT/disconnect?ip=$ip"
            ;;
        7)
            read -p "Enter IP or ID (or q to abort): " target
            [[ "$target" == "q" || "$target" == "Q" ]] && continue

            if [[ "$target" =~ ^[0-9]+$ ]]; then
                curl -s -X POST "http://$HOST:$PORT/disconnect_oldest?ID=$target"
            else
                curl -s -X POST "http://$HOST:$PORT/disconnect_oldest?ip=$target"
            fi
            ;;
        8)
            read -p "Enter ID(s), comma separated (or q to abort): " cidlist
            [[ "$cidlist" == "q" || "$cidlist" == "Q" ]] && continue

            IFS=',' read -ra IDS <<< "$cidlist"
            for cid in "${IDS[@]}"; do
                cid_trimmed=$(echo "$cid" | xargs)
                [[ -n "$cid_trimmed" ]] && \
                    curl -s -X POST "http://$HOST:$PORT/disconnect_id?ID=$cid_trimmed"
            done
            ;;
        9)
            curl -s -X POST "http://$HOST:$PORT/hexdump/on"
            ;;
        10)
            curl -s -X POST "http://$HOST:$PORT/hexdump/off"
            ;;
        11)
            read -p "Enter ID (or q to abort): " cid
            [[ "$cid" == "q" || "$cid" == "Q" ]] && continue

            if [[ "$cid" =~ ^[0-9]+$ ]]; then
                curl -s -X POST "http://$HOST:$PORT/disconnect_upstream?ID=$cid"
            else
                echo "Invalid ID (must be numeric)"
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac

    echo
    read -p "Press ENTER to continue..."
done
