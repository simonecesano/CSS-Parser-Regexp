use CSS::Parser::Regexp;
use Test::More tests => 1;
use Test::Deep;

my $p = CSS::Parser::Regexp->new;

my $css = <<'CSS';
@charset "utf-8";

@namespace url(http://www.w3.org/1999/xhtml);
@namespace svg url(http://www.w3.org/2000/svg);

@supports (display: flex) {
  @media screen and (min-width: 900px) {
    article {
      display: flex;
    }

    title {
      display: none;
    }
  }
  @media screen and (max-width: 900px) {
    article {
      display: inline-block;
    }

    title {
      display: block;
    }
  }
}
@counter-style thumbs {
  system: cyclic;
  symbols: "\1F44D";
  suffix: " ";
}

@font-face {
  font-family: "Open Sans";
  src: url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2"),
       url("/fonts/OpenSans-Regular-webfont.woff") format("woff");
}

.someclass {
    color: limegreen;
    font-size: 12pt;
}

CSS
    ;

my $r = $p->parse($css);

my $stringified = <<'STR'
@charset     "utf-8";

@namespace     url(http://www.w3.org/1999/xhtml);
@namespace     svg url(http://www.w3.org/2000/svg);

@font-face {
    font-family : "Open Sans";
    src : url("/fonts/OpenSans-Regular-webfont.woff2") format("woff2"), url("/fonts/OpenSans-Regular-webfont.woff") format("woff");
}

@counter-style thumbs {
    suffix : " ";
    symbols : "\1F44D";
    system : cyclic;
}

.someclass {
    color : limegreen;
    font-size : 12pt;
}

@supports (display: flex) {
    @media screen and (max-width: 900px) {
        article {
            display : inline-block;
        }

        title {
            display : block;
        }

    }

    @media screen and (min-width: 900px) {
        article {
            display : flex;
        }

        title {
            display : none;
        }

    }

}

STR
    ;

ok($stringified eq $r->stringify, 'stringify');
