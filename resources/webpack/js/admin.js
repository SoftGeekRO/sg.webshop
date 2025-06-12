document.addEventListener('DOMContentLoaded', function() {
  // Add icons to platform dropdown options
  document.querySelectorAll('.field-platform select').forEach(select => {
    Array.from(select.options).forEach(option => {
      const iconClass = `fas fa-${option.value}`;
      option.text = `<i class="${iconClass}"></i> ${option.text}`;
    });
  });
});
