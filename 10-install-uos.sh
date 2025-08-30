download_unifi() {
  local file="${WORKDIR}/$(basename "${UNIFI_URL}")"

  if [[ -s "$file" ]]; then
    local cur
    cur="$(md5sum "$file" | awk '{print $1}')"
    if [[ "$cur" == "$EXPECTED_MD5" ]]; then
      echo "[+] Using existing verified file: $file"
      chmod +x "$file"
      printf '%s\n' "$file"
      return
    else
      echo "[!] Existing file MD5 mismatch (expected $EXPECTED_MD5, got $cur). Re-downloading…"
    fi
  fi

  echo "[+] Downloading UniFi OS Server:"
  echo "    $UNIFI_URL"
  if command -v pv >/dev/null 2>&1; then
    # Fetch headers to get content length (for pv)
    size=$(curl -sI "$UNIFI_URL" | awk '/Content-Length/ {print $2}' | tr -d '\r')
    if [[ -n "$size" ]]; then
      curl -fsSL "$UNIFI_URL" | pv -s "$size" -i 1 > "$file"
    else
      curl -fsSL "$UNIFI_URL" | pv -i 1 > "$file"
    fi
  else
    # Fallback: curl’s built-in progress
    curl -# -L -o "$file" "$UNIFI_URL"
  fi
  chmod +x "$file"

  local new
  new="$(md5sum "$file" | awk '{print $1}')"
  if [[ "$new" != "$EXPECTED_MD5" ]]; then
    echo "[x] MD5 mismatch (expected $EXPECTED_MD5, got $new)"; exit 1
  fi
  echo "[+] Downloaded and verified: $file"
  printf '%s\n' "$file"
}
