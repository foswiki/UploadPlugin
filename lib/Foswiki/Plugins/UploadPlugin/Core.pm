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

package Foswiki::Plugins::UploadPlugin::Core;

use strict;
require Foswiki::Func;    # The plugins API
require Foswiki::Sandbox;
use Error qw( :try );

use vars qw($baseWeb $baseTopic);

use constant DEBUG => 1; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- UploadPlugin - $_[0]\n" if DEBUG;
}

##############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;
}

##############################################################################
sub handleUploadForm {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $template = Foswiki::Func::readTemplate('uploadplugin');
  my $comment = $params->{comment} || 'on';
  my $target = $params->{target} || 'on';
  my $multiple = $params->{multi} || 'on';
  my $embed = $params->{embed} || 'off';
  my $ajax = $params->{ajax} || 'off';

  my @metas;
  foreach my $key ('onsuccess', 'onerror') {
    my $val = $params->{$key};
    next unless $val;
    $val = "function(uploader) { $val }" unless $val =~ /^function/;
    push @metas, "<meta name=\"foswiki.UploadPlugin.$key\" content=\"$val\">";
  }
  if (@metas) {
    my $header = join("\n", @metas);
    Foswiki::Func::addToHEAD('UPLOADPLUGIN::METADATA', "\n".$header, 'JQUERYPLUGIN');
  }

  my $context = Foswiki::Func::getContext();
  $context->{'UploadPlugin_comments'} = 1 if $comment eq 'on';
  $context->{'UploadPlugin_target'} = 1 if $target eq 'on';
  $context->{'UploadPlugin_multiple'} = 1 if $multiple eq 'on';
  $context->{'UploadPlugin_embed'} = 1 if $embed eq 'on';
  $context->{'UploadPlugin_ajax'} = 1 if $ajax eq 'on';

  my $result = Foswiki::Func::expandTemplate('uploadform');

  undef $context->{'UploadPlugin_comments'};
  undef $context->{'UploadPlugin_target'};
  undef $context->{'UploadPlugin_multiple'};
  undef $context->{'UploadPlugin_embed'};
  undef $context->{'UploadPlugin_ajax'};

  return $result;
}

##############################################################################
sub handleRestUpload {
  my ($session, $subject, $verb, $response) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $uploads = $query->uploads();
  my $topic = $query->param('topic');
  my $useAjax = $query->param('useajax') || 'off';
  my $web;

  if ( $query && $query->method() && uc($query->method()) ne 'POST') {
    returnRESTResult($response, 405, "Method not Allowed");
    return;
  }

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName("", $topic);

  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', Foswiki::Func::getWikiName(), undef, $topic, $web)) {
    if ($useAjax eq 'on') {
      returnRESTResult($response, 403, "Access denied");
    } else {
      throw Foswiki::OopsException(
        'accessdenied',
        status => 403,
        def    => 'topic_access',
        web    => $web,
        topic  => $topic,
        params => [ 'CHANGE', 'Access denied' ]
      );
    }
    return;
  }

  writeDebug("called handleRestUpload($web, $topic)");

  my $maxSize = Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT');
  $maxSize = 0 unless ($maxSize =~ /([0-9]+)/o);

  my $found = 0;
  foreach my $fileName (keys %$uploads) {
    $found = 1;
    my $upload = $uploads->{$fileName};

    my $tmpFileName = $upload->tmpFileName;
    my $origName;
    $fileName =~ s|([^/\\]*$)|$1|;
    ($fileName, $origName) =
      Foswiki::Sandbox::sanitizeAttachmentName($fileName);

    my $stream = $upload->handle;
    my $fileSize;
    my $fileDate;
    if ($stream) {
      my @stats = stat $stream;
      $fileSize = $stats[7];
      $fileDate = $stats[9];
    }

    unless ($fileSize && $fileName) {
      if ($useAjax eq 'on') {
        returnRESTResult($response, 500, "Zero-sized file upload of '$fileName'");
      } else {
        throw Foswiki::OopsException(
          'attention',
          def    => 'zero_size_upload',
          web    => $web,
          topic  => $topic,
          params => [ ( $fileName || '""' ) ]
        );
      }
      close($stream) if $stream;
      return; 
    }

    if ($maxSize && $fileSize > $maxSize * 1024) {
      if ($useAjax eq 'on') {
        returnRESTResult($response, 500, "Oversized upload of '$fileName'");
      } else {
        throw Foswiki::OopsException(
          'attention',
          def    => 'oversized_upload',
          web    => $web,
          topic  => $topic,
          params => [ $fileName, $maxSize ]
        );
      }
      close($stream) if $stream;
      return;
    }

    writeDebug("useAjax=$useAjax, fileName=$fileName, origName=$origName, tmpFileName=$tmpFileName ");

    my $info = $upload->uploadInfo;
    if (DEBUG) {
      foreach (keys %$info) {
        writeDebug("info - $_=$info->{$_}");
      }
    }
    my $id = $info->{'Content-Disposition'};
    $id =~ s/^.*\bname="filepath(.*?)".*$/$1/g;
    writeDebug("id=$id");
   
    my $fileComment = $query->param('filecomment'.$id); 
    unless (defined $fileComment) {
      writeDebug("filecomment$id not found in query ... reading from topic");
      # get prev comment as we override it otherwise
      my ($meta, undef) = Foswiki::Func::readTopic($web, $topic);
      my $attrs = $meta->get( 'FILEATTACHMENT', $fileName );
      $fileComment = $attrs->{comment} || '';
    }
  
    my $createLink = $query->param('createlink'.$id) || '';
    my $hideFile = $query->param('hidefile'.$id) || '';

    writeDebug("fileComment=$fileComment"); 
    writeDebug("createLink=$createLink"); 
    writeDebug("hideFile=$hideFile"); 

    my $error;
    try {
      $error = Foswiki::Func::saveAttachment(
        $web, $topic, $fileName, {
          dontlog     => !$Foswiki::cfg{Log}{upload},
          comment     => $fileComment,
          hide        => $hideFile,
          createlink => $createLink,
          stream      => $stream,
          filesize    => $fileSize,
          filedate    => $fileDate,
          tmpFilename => $tmpFileName,
        });
    } catch Error::Simple with {
      $error = shift->{-text};
    };

    if ($error) {
      close($stream) if $stream;
      if ($useAjax eq 'on') {
        returnRESTResult($response, 500, $error);
      } else {
        throw Foswiki::OopsException(
          'attention',
          def    => 'save_error',
          web    => $web,
          topic  => $topic,
          params => [ $error ]
        );
      }
      return;
    }

    close($stream) if $stream;
  }

  unless ($found) {
    if ($useAjax eq 'on') {
      returnRESTResult($response, 500, "Zero-sized file upload");
    } else {
      throw Foswiki::OopsException(
        'attention',
        def    => 'zero_size_upload',
        web    => $web,
        topic  => $topic,
        params => [ '""' ]
      );
    }
  }

  if ($useAjax eq 'on') {
    $response->header(
      -status  => 200,
      -type    => 'text/html',
    );
  } else {
    my $url = Foswiki::Func::getViewUrl($web, $topic);
    Foswiki::Func::redirectCgiQuery($query, $url);
  }

  return;
}

##############################################################################
sub returnRESTResult {
  my ($response, $status, $text) = @_;

  $response->header(
    -status  => $status,
    -type    => 'text/html',
  );

  $response->print($text);
  writeDebug($text) if $status >= 400;
}

1;
