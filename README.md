# CSS::Parser::Regexp - a regexp-based CSS parses with at-rule support

## SYNOPSIS
    
    use CSS::Parser::Regexp;
    use Data::Dumper;
    
    $\ = "\n";
    
    my $css = <<CSS
    .someclass {
        color: limegreen;
        font-size: 12pt;
    }
    CSS
    ;
    
    my $p = CSS::Parser::Regexp->new;
    
    $p->parse($css);
    
    print Dumper($p->rules);
    
    print Dumper($p->to_tree);
    
    print $p->stringify;

## DESCRIPTION

This module parses CSS with at-rules into rule lists or trees, and stringifies it back

## FUNCTIONS

### new

    my $p = CSS::Parser::Regexp->new;

Creates a new CSS::Parser::Regexp instance.

### parse

    $p->parse($css);

Parses a CSS string. Returns the CSS::Parser::Regexp object.

### rules

    my $rules = $p->parse($css)->rules

Returns the list of parsed rules as an arrayref.

### stringify

    my $rules = $p->parse($css)->stringify

Returns the list of parsed rules stringified into CSS.

### to_tree

    my $rules = $p->parse($css)->to_tree

Returns the list of parsed rules as a tree of hashrefs

## TO DO

- better sorting of rules in stringify
- documenting the rule list and tree structures
- functionality for adding/removing rules

## SEE ALSO

- CSS
- CSS::DOM
- CSS::Tiny

## BUGS and CAVEATS

This module is tested against Bootstrap, Normalize.css and Pure.css. I don't know if there is gnarly CSS out there that this module fails against.

## AUTHORS

Simone Cesano <scesano@cpan.org>

## COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Simone Cesano.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

