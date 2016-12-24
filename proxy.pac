function FindProxyForURL(url, host) {
  if (shExpMatch(host, "msg.nicovideo.jp"))
  {
    return "PROXY 127.0.0.1:8080; DIRECT";
  }

  return "DIRECT";
}
