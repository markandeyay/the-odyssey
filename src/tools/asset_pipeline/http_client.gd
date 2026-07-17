extends Node

const USER_AGENT: String = "TheOdysseyWorldAssetPipeline/0.1 (Godot 4.6.1; contact: project maintainer)"
const REQUEST_TIMEOUT_SECONDS: float = 60.0
const MAX_DOWNLOAD_BYTES: int = 536870912


func get_json(url: String) -> Dictionary:
	var response: Dictionary = await get_bytes(url)
	if not bool(response.get("ok", false)):
		return response
	var body: PackedByteArray = response.get("body", PackedByteArray()) as PackedByteArray
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return _failure("Invalid JSON from %s at line %d: %s" % [url, json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary:
		return _failure("Expected a JSON object from %s" % url)
	return {"ok": true, "data": json.data}


func get_bytes(url: String) -> Dictionary:
	return await _request(url, "")


func download(url: String, destination_path: String) -> Dictionary:
	return await _request(url, destination_path)


func _request(url: String, destination_path: String) -> Dictionary:
	if not url.begins_with("https://"):
		return _failure("Asset pipeline refuses non-HTTPS URL: %s" % url)
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.timeout = REQUEST_TIMEOUT_SECONDS
	request_node.download_chunk_size = 65536
	request_node.body_size_limit = MAX_DOWNLOAD_BYTES
	if not destination_path.is_empty():
		request_node.download_file = ProjectSettings.globalize_path(destination_path)
	add_child(request_node)
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/json, application/octet-stream;q=0.9, */*;q=0.8",
	])
	var start_error: Error = request_node.request(url, headers, HTTPClient.METHOD_GET)
	if start_error != OK:
		request_node.queue_free()
		return _failure("Unable to start request for %s: %s" % [url, error_string(start_error)])
	var completed: Array = await request_node.request_completed
	var transport_result: int = int(completed[0])
	var response_code: int = int(completed[1])
	var body: PackedByteArray = completed[3] as PackedByteArray
	request_node.queue_free()
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return _failure("Network request failed for %s (result %d)" % [url, transport_result])
	if response_code < 200 or response_code >= 300:
		return _failure("HTTP %d from %s" % [response_code, url])
	return {"ok": true, "status": response_code, "body": body}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
