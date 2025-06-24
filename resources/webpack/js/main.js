import backToTop from './tools/back-to-top';

$(function() {
  backToTop();

  if (typeof(mermaid) !== 'undefined') {
    mermaid.initialize({ startOnLoad: true });
  }

});
