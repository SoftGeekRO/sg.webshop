function backToTop() {
  /**
   * Back to top button
   */
  let $backtotop = $('.back-to-top');

  if ($backtotop.length) {
    const toggleBacktotop = function() {
      if ($(window).scrollTop() > 100) {
        $backtotop.addClass('active');
      } else {
        $backtotop.removeClass('active');
      }
    };

    // On page load
    $(window).on('load', toggleBacktotop);

    // On scroll
    $(document).on('scroll', toggleBacktotop);
  }
}

export default backToTop;
