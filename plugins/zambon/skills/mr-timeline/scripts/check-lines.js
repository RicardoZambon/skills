// Paste into the browser pane (javascript_tool) on the served board after it has drawn.
// For every feature it samples each dependency line along its length and reports any point that
// lands on a label or dot belonging to neither end of that line. Expect "no crossings" for all.
(() => {
  const out = [];
  for (const section of document.querySelectorAll('details.feature')) {
    const boxes = [...section.querySelectorAll('[data-node]')].map((node) => ({
      id: node.dataset.node,
      label: node.querySelector('.node-label').getBoundingClientRect(),
      dot: node.querySelector('.dot').getBoundingClientRect()
    }));
    const hits = new Set();
    const lines = section.querySelectorAll('path.link');
    for (const path of lines) {
      const length = path.getTotalLength();
      const matrix = path.getScreenCTM();
      for (let step = 6; step < length - 6; step += 3) {
        const point = path.getPointAtLength(step);
        const x = point.x * matrix.a + matrix.e;
        const y = point.y * matrix.d + matrix.f;
        for (const box of boxes) {
          if (box.id === path.dataset.from || box.id === path.dataset.to) continue;
          for (const [kind, rect] of [['label', box.label], ['dot', box.dot]]) {
            if (rect.width && x > rect.left && x < rect.right && y > rect.top && y < rect.bottom) {
              hits.add(`${path.dataset.from} > ${path.dataset.to} crosses the ${kind} of ${box.id}`);
            }
          }
        }
      }
    }
    out.push(`${section.id}: ${boxes.length} MRs, ${lines.length} lines, ${hits.size ? [...hits].join(' | ') : 'no crossings'}`);
  }
  return out;
})();
