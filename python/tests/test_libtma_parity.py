"""qe-ena compiles libtma's accumulate_stanza (libqe's phase 5 split); it must
match qe-lib's qe.accumulation copy (kept until libqe 0.2.0) exactly.
Skipped once qe-lib drops it."""
import numpy as np
import pytest

from ena import _libena

# qe.accumulation is an attribute of qe-lib's extension, not an importable path.
qe_acc = getattr(pytest.importorskip("qe"), "accumulation", None)
if qe_acc is None:
    pytest.skip("qe-lib no longer has accumulation", allow_module_level=True)

rng = np.random.default_rng(11)
COUNTS = rng.integers(0, 3, (12, 4)).astype(np.float64)


@pytest.mark.parametrize("back,forward,binary,ordered", [
    (1, 0, True, False), (3, 1, False, False), (4, 0, True, True), (2**31 - 1, 0, False, False),
])
def test_accumulate_stanza_matches_qe_lib(back, forward, binary, ordered):
    np.testing.assert_array_equal(
        _libena.accumulate_stanza(COUNTS, back, forward, binary, ordered),
        qe_acc.accumulate_stanza(COUNTS, back, forward, binary, ordered))
