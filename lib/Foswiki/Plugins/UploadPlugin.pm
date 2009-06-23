# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::UploadPlugin;

use strict;

our $VERSION = '$Rev: 1340 $';
our $RELEASE = '1.00';
our $SHORTDESCRIPTION = 'Attach multiple files to a topic in one go';
our $NO_PREFS_IN_TOPIC = 1;
our $doneInit;
our $baseWeb;
our $baseTopic;

##############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('UPLOADFORM', \&handleUploadForm);
  Foswiki::Func::registerRESTHandler('upload', \&handleRestUpload);

  $doneInit = 0;
  return 1;
}

###############################################################################
sub init {
  return if $doneInit;
  $doneInit = 1;
  require Foswiki::Plugins::UploadPlugin::Core;
  Foswiki::Plugins::UploadPlugin::Core::init($baseWeb, $baseTopic);
}

##############################################################################
sub handleUploadForm {
  init();
  Foswiki::Plugins::UploadPlugin::Core::handleUploadForm(@_);
}

##############################################################################
sub handleRestUpload {
  init();
  Foswiki::Plugins::UploadPlugin::Core::handleRestUpload(@_);
}

##############################################################################
sub DISafterSaveHandler {
  #my ( $text, $topic, $web, $meta ) = @_;

  # only in save context
  return unless Foswiki::Func::getContext()->{'save'};

  init();
  Foswiki::Plugins::UploadPlugin::Core::afterSaveHandler(@_);
}

1;

