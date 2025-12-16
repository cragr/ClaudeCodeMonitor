import XCTest
@testable import ClaudeCodeMonitor

final class PrometheusDecodingTests: XCTestCase {

    // MARK: - Instant Query Response Decoding

    func testDecodeInstantQueryResponse() throws {
        let json = """
        {
            "status": "success",
            "data": {
                "resultType": "vector",
                "result": [
                    {
                        "metric": {
                            "__name__": "up",
                            "job": "prometheus"
                        },
                        "value": [1702000000.123, "1"]
                    }
                ]
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusQueryResult>.self,
            from: data
        )

        XCTAssertEqual(response.status, "success")
        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.data?.resultType, "vector")
        XCTAssertEqual(response.data?.result.count, 1)

        let result = response.data?.result.first
        XCTAssertEqual(result?.metric["__name__"], "up")
        XCTAssertEqual(result?.metric["job"], "prometheus")
        XCTAssertEqual(result?.metricName, "up")
        XCTAssertNotNil(result?.value)
        XCTAssertEqual(result?.value?.value, "1")
        XCTAssertEqual(result?.value?.doubleValue, 1.0)
    }

    func testDecodeRangeQueryResponse() throws {
        let json = """
        {
            "status": "success",
            "data": {
                "resultType": "matrix",
                "result": [
                    {
                        "metric": {
                            "__name__": "claude_code_token_usage",
                            "model": "claude-3-sonnet"
                        },
                        "values": [
                            [1702000000.0, "100"],
                            [1702000060.0, "150"],
                            [1702000120.0, "200"]
                        ]
                    }
                ]
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusQueryResult>.self,
            from: data
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.data?.resultType, "matrix")
        XCTAssertEqual(response.data?.result.count, 1)

        let result = response.data?.result.first
        XCTAssertEqual(result?.metric["model"], "claude-3-sonnet")
        XCTAssertNotNil(result?.values)
        XCTAssertEqual(result?.values?.count, 3)
        XCTAssertEqual(result?.values?[0].value, "100")
        XCTAssertEqual(result?.values?[1].doubleValue, 150.0)
        XCTAssertEqual(result?.values?[2].doubleValue, 200.0)
    }

    func testDecodeErrorResponse() throws {
        let json = """
        {
            "status": "error",
            "errorType": "bad_data",
            "error": "invalid query"
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusQueryResult>.self,
            from: data
        )

        XCTAssertEqual(response.status, "error")
        XCTAssertFalse(response.isSuccess)
        XCTAssertEqual(response.errorType, "bad_data")
        XCTAssertEqual(response.error, "invalid query")
        XCTAssertNil(response.data)
    }

    func testDecodeBuildInfoResponse() throws {
        let json = """
        {
            "status": "success",
            "data": {
                "version": "2.47.0",
                "revision": "abc123",
                "branch": "HEAD",
                "buildUser": "root@localhost",
                "buildDate": "20231201-00:00:00",
                "goVersion": "go1.21.0"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusBuildInfo>.self,
            from: data
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.data?.version, "2.47.0")
        XCTAssertEqual(response.data?.goVersion, "go1.21.0")
    }

    func testDecodeTargetsResponse() throws {
        let json = """
        {
            "status": "success",
            "data": {
                "activeTargets": [
                    {
                        "labels": {
                            "job": "otel-collector",
                            "instance": "localhost:8889"
                        },
                        "scrapePool": "otel-collector",
                        "scrapeUrl": "http://localhost:8889/metrics",
                        "health": "up",
                        "lastError": "",
                        "lastScrape": "2023-12-01T00:00:00Z"
                    }
                ],
                "droppedTargets": []
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusTargetsResult>.self,
            from: data
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.data?.activeTargets.count, 1)
        XCTAssertEqual(response.data?.activeTargets.first?.labels["job"], "otel-collector")
        XCTAssertEqual(response.data?.activeTargets.first?.health, "up")
    }

    // MARK: - PrometheusValue Tests

    func testPrometheusValueDate() throws {
        let json = "[1702000000.0, \"42\"]"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(PrometheusValue.self, from: data)

        XCTAssertEqual(value.timestamp, 1702000000.0)
        XCTAssertEqual(value.value, "42")
        XCTAssertEqual(value.doubleValue, 42.0)
        XCTAssertEqual(value.date.timeIntervalSince1970, 1702000000.0)
    }

    func testPrometheusValueWithNaN() throws {
        let json = "[1702000000.0, \"NaN\"]"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(PrometheusValue.self, from: data)

        XCTAssertEqual(value.value, "NaN")
        // NaN comparison requires special handling
        XCTAssertTrue(value.doubleValue?.isNaN ?? false)
    }

    func testPrometheusValueWithInf() throws {
        let json = "[1702000000.0, \"+Inf\"]"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(PrometheusValue.self, from: data)

        XCTAssertEqual(value.value, "+Inf")
        XCTAssertEqual(value.doubleValue, Double.infinity)
    }

    // MARK: - Empty Result Tests

    func testDecodeEmptyResult() throws {
        let json = """
        {
            "status": "success",
            "data": {
                "resultType": "vector",
                "result": []
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            PrometheusResponse<PrometheusQueryResult>.self,
            from: data
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.data?.result.count, 0)
    }
}
