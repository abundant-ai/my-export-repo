Write api-change-guard as a CLI installed at /usr/local/bin/api-change-guard.

Invoke with two OpenAPI inputs plus an optional third logs file. An input may be a spec file or a directory that contains baseline.yaml and candidate.yaml. If both inputs are files, pick the baseline by preferring a filename containing baseline, otherwise choose the lexicographically smaller absolute path. If files are missing or parsing fails, print [] and exit 0.

Read OpenAPI 3. Collect operations by path and method where method is one of GET POST PUT PATCH DELETE HEAD OPTIONS TRACE in uppercase. Compare baseline to candidate and emit violations named ENDPOINT_REMOVED, PARAM_REQUIRED_ADDED, PARAM_TYPE_CHANGED, RESPONSE_200_REMOVED. New operations are additive only and not violations. If logs are supplied as JSON array of objects with path and method, a removed operation that appears there is HIGH severity, otherwise MEDIUM. All other violations are MEDIUM.

Always print a JSON array to stdout. Each item has rule path method message severity and object with absolute baseline_file candidate_file baseline_version candidate_version. Sort by path then method then rule.

Enforce semantic versioning using info.version in x.y.z form. With any breaking violation the candidate must bump major. With no breaking and at least one additive operation it must bump minor. Otherwise patch_or_equal is acceptable. When the observed bump disagrees add one SEMVER_MISMATCH with path info.version method N/A and a message that contains expected major or expected minor or expected patch_or_equal.



