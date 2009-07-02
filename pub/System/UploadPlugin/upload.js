/*
 * jQuery uploader plugin 1.0
 *
 * Copyright (c) 2009 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 */
(function($) {

  // extending jquery 
  $.fn.extend({
    uploader: function(options) {
      var opts = $.extend({}, $.Uploader.defaults, foswiki.UploadPlugin, options);
      return this.each(function() {
        new $.Uploader(this, opts);
      });
    }
  });
 
  // Uploader class **************************************************
  $.Uploader = function(elem, opts) {
    var self = this;
    self.container = $(elem);
    self.form = self.container.find("form:first");
    $.log("creating new  uploader for ");
    self.container.debug();
   
    // build element specific options. 
    // note you may want to install the Metadata plugin
    self.opts = $.extend({}, self.container.metadata(), opts);
  
    // bindings
    self.container.find(".add_button").click(function() {
      this.blur();
      self.addField();
      return false;
    });
    self.container.find(".remove_button").click(function() {
      this.blur();
      self.removeField();
      return false;
    });
  
    // ajaxification
    var oldBackground;
    var $buttonIcon;

    if (typeof(self.form.ajaxForm) != 'undefined') {
      self.form.ajaxForm({
          dataType: 'html',
          beforeSubmit: function(data, form, options) {
            if (typeof(foswikiStrikeOne) != 'undefined') {
              foswikiStrikeOne(form[0]);
            }
            // add notification and spinner
            $buttonIcon = self.form.find('.foswikiFormLast .jqButtonIcon');
            oldBackground = $buttonIcon.css('background-image');
            $buttonIcon.css('background-image', 'url('+foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/spinner/spinner.gif)');
            self.form.find(".msg").empty();
          },
          success: function(data, status) {
            // restore old icon and notify
            $buttonIcon.css('background-image', oldBackground);
            if (data) { // any data is an error message
              self.handleError('Alert', "Error: "+data);
            } else {
              self.handleError('Success', 'done');
              self.resetFields();
              if (typeof(self.opts.onsuccess) == 'function') {
                self.opts.onsuccess.call(this, self);
              }
              self.container.trigger("success.uploader");
            }
          },
          error: function(xhr, status) {
            // restore old icon and warn
            $buttonIcon.css('background-image', oldBackground);
            self.handleError('Alert', "Error: "+xhr.responseText);
            self.container.trigger("error.uploader");
            if (typeof(self.opts.onerror) == 'function') {
              self.opts.onerror.call(this, self);
            }
          }
      });
    }
  };

  // add a field to the form *********************************************
  $.Uploader.prototype.addField = function() {
    var self = this;
    $.log("called uploader::addField");
    var lastId = self.container.find(".upload:last input[type=file]").attr('name').replace(/[^0-9]/g, '');
    lastId++;
    var elem = self.container.find(".upload:first");
    elem = elem.clone().hide().appendTo(elem.parent()).slideDown(400);
    elem.find("input[type=file]").attr('name', "filepath"+lastId).val('');
    elem.find("input[type=text]").attr('name', "filecomment"+lastId).val('');
    return elem;
  };

  // remove a field to the form *****************************************
  $.Uploader.prototype.removeField = function() {
    var self = this;
    $.log("called removeField");
    if (self.container.find(".upload").length > 1) {
      return self.container.find(".upload:last").slideUp(400, function() {$(this).remove();});
    }
  };

  // reset the input field **********************************************
  $.Uploader.prototype.resetFields = function() {
    var self = this;
    self.container.find(".foswikiFileUpload").val(""); // empty the input boxes
    self.container.find(".upload:gt(0)").remove();
  };

  // display error messages *********************************************
  $.Uploader.prototype.handleError = function(type, msg) {
    var self = this;
    self.container.find(".msg").html("<div class='foswiki"+type+"'>"+msg+"</div>");
  };
 
  // default settings ****************************************************
  $.Uploader.defaults = {
    /*
    onsuccess: function () {},
    onerror: function () {}
    */
  };


  // initialisation
  $(function() {
    $(".jqUploader").uploader();
  });

})(jQuery);
