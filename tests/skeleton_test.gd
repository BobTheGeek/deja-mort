extends GdUnitTestSuite

## M0 smoke test. Proves the project loads, gdUnit4 runs, and CI is wired.
## Real sim tests arrive in M1 under tests/sim/.


func test_project_identity() -> void:
	assert_str(str(ProjectSettings.get_setting("application/config/name"))).is_equal("DÉJÀ MORT")


func test_mobile_renderer_is_configured() -> void:
	assert_str(str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))).is_equal("mobile")
