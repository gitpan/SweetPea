package SweetPea;
use 5.006;

=head1 NAME

SweetPea - A web framework that doesn't get in the way, or suck.

=cut

BEGIN {
    use Exporter();
    use vars qw( @ISA @EXPORT @EXPORT_OK );
    @ISA    = qw( Exporter );
    @EXPORT = qw(sweet);
}

use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use FindBin;
use File::Find;

=head1 VERSION

Version 2.3663

=cut

our $VERSION = '2.3663';

=head1 DESCRIPTION

SweetPea is a modern web application framework that is fast, scalable, and
light-weight. SweetPea has no dependencies so it runs everywhere Perl does.
SweetPea has a short learning curve and a common sense object-oriented API.

=head1 SYNOPSIS

Oh how Sweet web application development can be ...

    # from the command-line (requires SweetPea::Cli)
    sweetpea make -s
    
    use SweetPea;
    sweet->routes({
    
        '/' => sub {
            shift->forward('/way');
        },
        
        '/way' => sub {
            shift->html('I am the way the truth and the light!');
        }
        
    })->run;

=cut

=head1 NOTICE!

This POD is being rewritten and may appear incomplete. If so please refer to
L<SweetPea::Overview> for the original documentation, keep in mind that
the original documentation may/is probably out-dated.

Also Note!
The sweetpea application generator script has been moved to
L<SweetPea::Cli> and the usage and syntax has changed a bit.

=head1 METHODS

=head2 new

I<the `new` method is used to instantiate a new SweetPea object.>

new B<arguments>

=over 3

=item L<options|/"\%options">

=back

new B<usage and syntax>

    $self = SweetPea->new(\%options)
    
    takes 1 argument
        1st argument  - optional
            \%options - sweetpea runtime options
            
    example:
    my $self = sweet;
    
    my $self = SweetPea->new({
        local_session => 1
    });
    
    my $self = SweetPea->new({
        session_folder => '/tmp/site1'
    });

=cut

sub new {
    my $class   = shift;
    my $options = shift;
    my $self    = {};
    bless $self, $class;

    #declare config stuff
    $self->{store}->{application}->{html_content}     = [];
    $self->{store}->{application}->{action_discovery} = 1;
    $self->{store}->{application}->{content_type}     = 'text/html';
    $self->{store}->{application}->{path}             = $FindBin::Bin;
    $self->{store}->{application}->{local_session}    =
        $options->{local_session} ? $options->{local_session} : 0; # debugging
    $self->{store}->{application}->{session_folder}   =
        $options->{session_folder} if $options->{session_folder};
    
    return $self;
}

=head2 run

I<the `run` method is used to discover controllers and actions then
executes internal pre and post request processing routines.>

run B<arguments>

no arguments

run B<usage and syntax>

    $self = $self->run
    
    takes 0 arguments
    
    example:
    my $self = sweet;
    $self->run;

=cut

sub run {
    my $self = shift;
    $self->_plugins;
    $self->_self_check;
    $self->_init_dispatcher;
    return $self;
}

=head2 test

I<the `test` method is used to simulate processing requests from the
command line. Equivalent to the `run` method.>

test B<arguments> 

=over 3

=item L<route|/"$route"> L<options|/"\%options">

=back

test B<usage and syntax>

    $self = $self->test($route, \%options)
    
    takes 2 arguments
        1st argument  - optional
            $route    - sweetpea url route
        2nd argument  - optional
            \%options - sweetpea runtime options
            
    example:
    my $self = sweet->test;

=cut

sub test {
    my ($self, $route, $options) = @_;
    
    # set up testing environment
    $route = '/' unless $route;
    $self->{store}->{application}->{test}->{route} = 
    $ENV{SCRIPT_NAME}   = "/.pl";
    $ENV{PATH_INFO}     = "$route";
    $self->run($options);
}

=head2 mock

I<the `mock` method is used to process a sub-request and return the
output without breaking the existing request. Useful for fetching pages
to display or attach in email messages.>

mock B<arguments>

=over 3

=item L<route|/"$route">

=back

mock B<usage and syntax>

    $self = $self->mock($route, \%options)
    
    takes 2 arguments
        1st argument  - required
            $route    - url path
        2nd argument  - optional
            \%options - sweetpea runtime options
    
    example:
    my $self = sweet;
    my @content = $self->mock('/path');

=cut

sub mock {
    my ($self, $route, $options) = @_;
    # mock can only be run as a get request
    my $original_request    = $ENV{REQUEST_METHOD};
    my $original_pathinfo   = $ENV{PATH_INFO};
    $ENV{REQUEST_METHOD}    = 'GET';
    # set up mock runtime environment 
    $route = '/' unless $route;
    $self->{store}->{application}->{mock_run} = 1;
    $self->{store}->{application}->{mock_data} = [];
    $self->{store}->{application}->{test}->{route} = 
    $ENV{SCRIPT_NAME}       = "/.pl" unless $ENV{SCRIPT_NAME};
    $ENV{PATH_INFO}         = "$route";
    $self->run;
    $ENV{REQUEST_METHOD}    = $original_request;
    $ENV{PATH_INFO}         = $original_pathinfo;
    push @{$self->{store}->{application}->{mock_data}}, @{$self->html};
    my @return = @{$self->{store}->{application}->{mock_data}};
    $self->{store}->{application}->{mock_run} = 0;
    $self->{store}->{application}->{mock_data} = [];
    $self->{store}->{application}->{test}->{route} = '';
    return @return;
}

=head2 mock_data

I<the `mock_data` method is used by the `mock` method to store output from
various stages of the sub-processing.>

mock_data B<arguments>

=over 3

=item L<data|/"\@data">

=back

mock_data B<usage and syntax>

    $self->mock_data(@data);
    
    takes 1 argument
        1st argument  - required
            @data     - content to be pushed into the mock datastore for
                        later retrieval
            
    example:
    This method is/should be only used by the `mock` method.

=cut

sub mock_data {
    my ( $self, @data ) = @_;
    if (@data) {
        my @existing_data =
          $self->{store}->{application}->{mock_data}
          ? @{ $self->{store}->{application}->{mock_data} }
          : ();
        push @existing_data, @data;
        $self->{store}->{application}->{mock_data} = \@existing_data;
        return;
    }
    else {
        if ( $self->{store}->{application}->{mock_data} ) {
            my @content = @{ $self->{store}->{application}->{mock_data} };
            $self->{store}->{application}->{mock_data} = [];
            return \@content;
        }
    }
}

=head2 _plugins

I<the `_plugins` method, used by the `run` method, is used to process
pre-defined plugins and load user-defined plugins.>

_plugins B<arguments>

no arguments

_plugins B<usage and syntax>

    $self = $self->_plugins;
    
    takes 0 arguments
            
    example:
    This method is used mainly by the `run` method.

=cut

sub _plugins {
    my $self = shift;

    # NOTE! The database and email plugins are not used internally so changing
    # them to a module of you choice won't effect any core functionality. Those
    # modules/plugins should be configured in App.pm.
    # load modules using the following procedure, they will be available to the
    # application as $s->nameofobject.

    $self->plug(
        'cgi',
        sub {
            my $self = shift;
            return CGI->new;
        }
    );

    $self->plug(
        'cookie',
        sub {
            require 'CGI/Cookie.pm';
            my $self = shift;
            push @{ $self->{store}->{application}->{cookie_data} },
              CGI::Cookie->new(@_);
            return $self->{store}->{application}->{cookie_data}
              ->[ @{ $self->{store}->{application}->{cookie_data} } ];
        }
    );

    $self->plug(
        'session',
        sub {
            require 'CGI/Session.pm';
            my $self = shift;
            my $opts = {};
            if ($self->{store}->{application}->{session_folder}) {
                $opts->{Directory} =
                    $self->{store}->{application}->{session_folder};
            }
            else {
                my $session_folder = $ENV{HOME} || "";
                $session_folder = (split /[\;\:\,]/, $session_folder)[0]
                 if $session_folder =~ m/[\;\:\,]/;
                $session_folder =~ s/[\\\/]$//;
                CGI::Session->name("SID");
                if ( -d -w "$session_folder/tmp" ) {
                    $opts->{Directory} = "$session_folder/tmp";
                }
                else {
                    if ( -d -w $session_folder ) {
                        mkdir "$session_folder/tmp", 0777;
                    }
                    if ( -d -w "$session_folder/tmp" ) {
                        $opts->{Directory} = "$session_folder/tmp";
                    }    
                }
                if ($self->{store}->{application}->{local_session}) {
                    mkdir "sweet"
                    unless -e
                    "$self->{store}->{application}->{path}/sweet";
                    
                    mkdir "sweet/sessions"
                    unless -e
                    "$self->{store}->{application}->{path}/sweet/sessions";
                    
                    $opts->{Directory} = 'sweet/sessions';
                }
            }
            my $sess = CGI::Session->new("driver:file", undef, $opts);
            $sess->flush;
            return $sess;
        }
    );

    # load non-core plugins from App.pm
    if (-e "sweet/App.pm") {
        eval 'require q(App.pm)';
        if ($@) {
            warn $@;
        }
        else {
            eval { App->plugins($self) };
        }
    }
    return $self;
}

=head2 _load_path_and_actions

I<the `_load_path_and_actions` method is used to auto-discover Controllers
and Actions, create the actions table, by treversing the Controllers
folder.>

_load_path_and_actions B<arguments>

no arguments

_load_path_and_actions B<usage and syntax>

    \%actions = $self->_load_path_and_actions;
    
    takes 0 arguments
            
    example:
    This method is use by the `run` method. And is not called manually.

=cut

sub _load_path_and_actions {
    my $self = shift;

    if ( $self->application->{action_discovery} ) {
        if (-e $self->application->{path} . '/sweet/application/Controller') {
            my $actions = {};
            find( \&_load_path_actions,
                $self->application->{path} . '/sweet/application/Controller' );
    
            sub _load_path_actions {
                no warnings 'redefine';
                no strict 'refs';
                my $name  = $File::Find::name;
                my $magic = '';
                my @dir   = ();
                if ( $name =~ /.pm$/ ) {
                    require $name;
                    my $controller = $name;
                    $controller =~ s/\\/\//g;    # convert non-unix paths
                    $controller =~ s/.*Controller\/(.*)\.pm$/$1/;
                    my $controller_ref = $controller;
                    $controller_ref =~ s/\//\:\:/g;
                    @dir = split /\//, $controller;
                    open( INPUT, "<", $name )
                      or die "Couldn't open $name for reading: $!\n";
                    my @code = <INPUT>;
                    my @routines = grep { /^sub\s?(.*)[\s\n]{0,}?\{/ } @code;
                    $_ =~ s/sub//g foreach @routines;
                    $_ =~ s/[^a-zA-Z0-9\_\-]//g foreach @routines;
    
                    # dynamically create new (initialization routine)
                    my $new = "Controller::" . $controller_ref . "::_new"
                      if $controller_ref;
                    *{$new} = sub {
                        my $class = shift;
                        my $self  = {};
                        bless $self, $class;
                        return $self;
                      }
                      if $new;
    
                    foreach (@routines) {
    
                        # dynamically create method references
                        my $code =
                            '$actions->{lc("/$controller/$_")} = '
                          . 'sub{ my ($s, $class) = @_; if ($class) { return $class->'
                          . $_
                          . '($s) } else { $class = Controller::'
                          . $controller_ref
                          . '->_new; return $class->'
                          . $_
                          . '($s); } }';
                        eval $code;
                    }
                    close(INPUT);
                }
            }
            map {
                $self->application->{actions}->{$_} = $actions->{$_} if
                not defined $self->application->{actions}->{$_};
            } keys %{$actions};
        }
    }
    return $self->application->{actions};
}

sub _self_check {
    my $self = shift;

    # used to do something useful, not anymore
    my $path = $self->application->{path};
    return $self;
}

=head2 _init_dispatcher

I<the `_init_dispatcher` method is used to process the global, local, and
current request routines.>

_init_dispatcher B<arguments>

no arguments

_init_dispatcher B<usage and syntax>

    $self->_init_dispatcher;
    
    takes 0 arguments
            
    example:
    This method is use by the `run` method and is not called manually.

=cut

sub _init_dispatcher {
    my $self = shift;
    my $actions = $self->_load_path_and_actions() || {};
    my $path;
    
    # url parser - this is informative
    $self->_url_parser($actions);
    
    my $controller  = $self->{store}->{application}->{url}->{controller};
    my $action      = $self->{store}->{application}->{url}->{action};
    my $request     = $self->{store}->{application}->{url}->{here};
    my $handler     = '';
    
    # check/balance
       $controller  = '/' unless $controller;
    
       $handler     = $action ? "$controller/$action" : $controller;
       $handler     = $actions->{$handler} if $handler;
    my $package     = $controller;
    
    # hack
    if ($action) {
        $package =~ s/\/$action$//;
    }
    elsif ($package) {
        if ($package eq '/') {
            $package = '';
        }
    }

    # alter environment for testing
    if ($self->{store}->{application}->{test}->{route}) {
        $controller = $request;
        $package = '';
    }

    # restrict access to hidden methods (methods prefixed with an underscore)
    if ( $request =~ /.*\/_\w+$/ ) {
        if ($self->{store}->{application}->{mock_run}) {
            $self->mock_data("Access denied to private action $request.");
            return $self->finish;
        }
        print
        $self->cgi->header,
        $self->cgi->start_html('Access Denied To Private Action'),
        $self->cgi->h1('Access Denied'),
        $self->cgi->end_html;
        exit;
    }

    # try global index
    if ( ref($handler) ne "CODE" ) {        
        # last resort, revert to root controller index action
        if (exists $actions->{"/root/_index"}
            && (!$actions->{"$controller"}
            && !$actions->{"$package/_index"})) {
            $handler = $actions->{"/root/_index"};
        }        
    }
    
    if ( ref($handler) eq "CODE" ) {

        #run master _startup routine
        $actions->{"/root/_startup"}->($self)
          if exists $actions->{"/root/_startup"};

        #run user-defined begin routine or default to root begin
        $actions->{"$package/_begin"}->($self)
          if exists $actions->{"$package/_begin"};
        
        $actions->{"/root/_begin"}->($self)
          if exists $actions->{"/root/_begin"}
            && !$actions->{"$package/_begin"};

        #run user-defined response routines
        $handler->($self);

        #run user-defined end routine or default to root end
        $actions->{"$package/_end"}->($self)
          if exists $actions->{"$package/_end"};
        
        $actions->{"/root/_end"}->($self)
          if exists $actions->{"/root/_end"}
            && !$actions->{"$package/_end"};

        #run master _shutdown routine
        $actions->{"/root/_shutdown"}->($self)
          if exists $actions->{"/root/_shutdown"};

        #run pre-defined response routines
        $self->start();

        #run finalization and cleanup routines
        $self->finish();
    }
    else {
        if ($self->{store}->{application}->{mock_run}) {
            $self->mock_data("Resource not found.");
            return $self->finish;
        }
        # print http header
        print $self->cgi->header, $self->cgi->start_html('Resource Not Found'),
          $self->cgi->h1('Not Found'), $self->cgi->end_html;
        exit;
    }
}

=head2 _url_parser

I<the `_url_parser` method is used to determine the true environment of
the current request as well as parse vaiable data in the url path.>

_url_parser B<arguments>

no arguments

_url_parser B<usage and syntax>

    $boolean = $self->_url_parser;
    
    takes 0 argument
            
    example:
    This method is use by the `run` method and is not called manually.

=cut

sub _url_parser {
    my ($self, $actions) = @_;
    # this allows us to deduce the web root, true current path, etc
    
    my  $script  = $self->{store}->{application}->{dispatcher} || '\.pl';
    my  $root    = $self->cgi->script_name();
        $root    =~ s/$script//;
        $root    =~ s/(^\/+|\/+$)//g;
        $root    = "/$root";
    my  $here    = $self->cgi->path_info();
        $here    =~ s/(^\/+|\/+$)//g;
        $here    = "/$here";
    my  $path    = $here;
        $here    = $here ? "$root$here" : $root;
        $here    =~ s/^\/// if $here =~ /^\/{2,}/;
    
    # A: action finding
    $self->{store}->{application}->{'url'}->{root}       = $root;
    $self->{store}->{application}->{'url'}->{here}       = $path;
    $self->{store}->{application}->{'url'}->{path}       = $here;
    
    my ($controller, $action);
    
    # 1. check if the path specified has a corresponding action
    if (ref($actions->{$path}) eq "CODE") {
        if ($here =~ m/\//) {
            my @act = split /\//, $path;
            $action = pop @act;
            $controller = join("/", @act);
            $controller = "/$controller" if $controller !~ m/^\//;
            $self->{store}->{application}->{'url'}->{controller} = $controller;
            $self->{store}->{application}->{'url'}->{action}     = $action;
            return 1;
        }
    }
    
    # 2. check if the path specified matches against inline url params
    foreach my $a (reverse sort keys %{$actions}) {
        my $pattern = $a;
        if ($pattern =~ /\:([\w]+)/) {
            my @keys = ($pattern =~ /\:([\w]+)/g);
            $pattern =~ s/\:[\w]+/\(\.\*\)/gi;
            my @values = $path =~ /$pattern/;
            if (scalar(@keys) == scalar(@values)) {
                for (my $i = 0; $i < @keys; $i++) {
                    $self->cgi->param(-name => $keys[$i],
                                      -value => $values[$i]);
                }
                $controller = "$a";
                $action     = "";
                $self->{store}->{application}->{'url'}->{controller} = $controller;
                $self->{store}->{application}->{'url'}->{action}     = $action;
                return 1;
            }
        }
    }
    
    # 3. check if the path specified matched against a paths with wildcards
    foreach my $a (reverse sort keys %{$actions}) {
        my $pattern = $a;
        if ($pattern =~ /\*/) {
            $pattern =~ s/\*/\(\.\*\)/;
            if ($path =~ m/$pattern/) {
                if ($0 && $1) {
                    $self->cgi->param(-name => '*', -value => $1);
                    $controller = "$a";
                    $action     = "";
                    $self->{store}->{application}->{'url'}->{controller} = $controller;
                    $self->{store}->{application}->{'url'}->{action}     = $action;
                    return 1;
                }
            }
        }
    }
    
    # 4. perform recursion tests as a last ditch effort
    if ($path =~ m/\//) {
        my @acts = split /\//, $path;
        my @trail = ();
        my $possibilities = @acts;
        for (my $i = 0; $i < $possibilities; $i++) {
            my $a = $acts[$i];
            if (@acts > 1) {
                if (ref($actions->{join("/", @acts)}) eq "CODE") {
                    $action     = pop @acts;
                    $controller = join("/", @acts);
                    $self->{store}->{application}->{'url'}->{controller} = $controller;
                    $self->{store}->{application}->{'url'}->{action}     = $action;
                    $self->cgi->param(-name => '*', -value => join("/", reverse @trail));
                    return 1;
                }
                else {
                    # wow, still nothing, look for local index
                    if (ref($actions->{join("/", @acts)."/_index"}) eq "CODE") {
                        $action     = "_index";
                        $controller = join("/", @acts);
                        $self->{store}->{application}->{'url'}->{controller} = join("/", @acts);
                        $self->{store}->{application}->{'url'}->{action}     = $action;
                        $self->cgi->param(-name => '*', -value => join("/", reverse @trail));
                        return 1;
                    }
                }
                push @trail, pop @acts;
            }
            else {
                if (ref($actions->{"/$acts[0]"}) eq "CODE") {
                    $controller = "/$acts[0]";
                    $actions    = "";
                    $self->{store}->{application}->{'url'}->{controller} = $controller;
                    $self->{store}->{application}->{'url'}->{action}     = $action;
                    $self->cgi->param(-name => '*', -value => join("/", reverse @trail));
                    return 1;
                }
                else {
                    # this better work, look for local index
                    if (ref($actions->{"/$acts[0]/_index"}) eq "CODE") {
                        $action     = "_index";
                        $controller = "/$acts[0]";
                        $self->{store}->{application}->{'url'}->{controller} = $controller;
                        $self->{store}->{application}->{'url'}->{action}     = $action;
                        $self->cgi->param(-name => '*', -value => join("/", reverse @trail));
                        return 1;
                    }
                }
            }
        }
    }
    
    return 0;
}

=head2 start

I<the `start` method is used to print header information to the browser
as well as perform other pre-print activities.>

start B<arguments>

no arguments

start B<usage and syntax>

    $self->start;
    
    takes 0 arguments
            
    example:
    This method is use by the `_init_dispatcher` method and is not called
    manually.

=cut

sub start {
    my $self = shift;

    # handle session
    if ( defined $self->session ) {
        $self->session->expire(
            defined $self->application->{session}->{expiration}
            ? $self->application->{session}->{expiration}
            : '1h' );
        $self->cookie(
            -name  => $self->session->name,
            -value => $self->session->id
        );
    }
    
    unless ($self->{store}->{application}->{mock_run}) {
        print $self->cgi->header(
            -type   => $self->application->{content_type},
            -status => 200,
            -cookie => $self->cookies
        );
    }
}

=head2 finish

I<the `finish` method is used to finalize the request and perform all
last-minute activities.>

finish B<arguments>

no arguments

finish B<usage and syntax>

    $self->finish;
    
    takes 0 arguments
            
    example:
    This method is use by the `_init_dispatcher` method and is not called
    manually.

=cut

sub finish {
    my $self = shift;

    # return captured data for mock transactions
    if ($self->{store}->{application}->{mock_run}) {
        $self->session->flush();
        return 1;
    }

    # print gathered html
    foreach ( @{ $self->html } ) {
        print "$_\n";
    }

    # commit session changes if a session has been created
    $self->session->flush();
}

=head2 forward

I<the `forward` method is used to jump between actions (sub routines) to
process related information then returns to the original action to finish
processing.>

forward B<arguments>

=over 3

=item L<route|/"$route">

=item L<self|/"$self">

=back

forward B<usage and syntax>

    $self->forward($route, $self);
    
    takes 2 arguments
        1st argument  - required
            $route    - display help for a specific command
        2nd argument  - optional
            $self     - The current class, used as a reference
            
    example:
    my $self = sweet;
    $self->routes({
        '/' => sub {
            shift->forward('/more');
            print ', buddy';
        }
        '/more' => sub {
            print '... here i am :)';
        }
    });
    
    # prints here i am, buddy

=cut

sub forward {
    my ( $self, $path, $class ) = @_;

    #run requested routine
    $self->application->{actions}->{"$path"}->( $self, $class ) if
    exists $self->application->{actions}->{"$path"};
}

=head2 detach

I<the `detach` method is used to jump between actions (sub routines) to
process related information but does NOT return to the original action to
finish processing. Actually it invokes the finalization routines and
the exits.>

detach B<arguments>

=over 3

=item L<route|/"$route">

=item L<self|/"$self">

=back

detach B<usage and syntax>

    $self->detach($route, $self);
    
    takes 2 arguments
        1st argument  - required
            $route    - display help for a specific command
        2nd argument  - optional
            $self     - The current class, used as a reference
            
    example:
    my $self = sweet;
    $self->routes({
        '/' => sub {
            shift->detach('/more');
            print ', buddy';
        }
        '/more' => sub {
            print '... here i am :)';
        }
    });
    
    # prints here i am

=cut

sub detach {
    my ( $self, $path, $class ) = @_;
    $self->forward( $path, $class );
    $self->start();
    $self->finish();
    exit;
}

=head2 redirect

I<the `redirect` method is used to redirect the browser to an alternate
resource.>

redirect B<arguments>

=over 3

=item L<url|/"$url">

=back

redirect B<usage and syntax>

    $self->redirect($url);
    
    takes 1 argument
        1st argument  - required
            $url      - absolute or relative url
            
    example:
    my $self = sweet;
    $self->redirect('http://www.sweetpea.com');
    $self->redirect('/static/index.html');

=cut

sub redirect {
    my ( $self, $url ) = @_;
    if ($self->{store}->{application}->{mock_run}) {
        $self->mock_data("Attempted to redirect to url $url.");
        return $self->finish;
    }
    $url = $self->url($url) unless $url =~ /^http/;
    print $self->cgi->redirect($url);
    exit;
}

=head2 store

I<the `store` method is used to return the SweetPea application stash
object.>

store B<arguments>

no arguments

store B<usage and syntax>

    my $stash = $self->store;
    
    takes 0 arguments
            
    example:
    my $self = sweet;
    my $stash = $self->store;
    $self->store->{foo} = 'bar';
    print $self->store->{foo};
    
    # prints 'bar'

=cut

sub store {
    my $self = shift;
    return $self->{store};
}

=head2 application

I<the `application` method is used to return a special section of the
sweetpea stash reserved for application configuration variables.>

application B<arguments>

no arguments

application B<usage and syntax>

    $self->application;
    
    takes 0 arguments
            
    example:
    my $self = sweet;
    my $stash = $self->application;
    $self->application->{foo} = 'bar';
    print $self->application->{foo};
    
    # prints 'bar'

=cut

sub application {
    my $self = shift;
    return $self->{store}->{application};
}

=head2 content_type

I<the `content_type` method is used to set the type of content the browser
should expect to be returned.>

content_type B<arguments>

=over 3

=item L<content_type|/"$content_type">

=back

content_type B<usage and syntax>

    $self->content_type($content_type);
    
    takes 1 argument
        1st argument        - required
            $content_type   - type of content to be returned
            
    example:
    my $self = sweet;
    $self->content_type('text/html');
    $self->content_type('text/plain');

=cut

sub content_type {
    my ( $self, $type ) = @_;
    $self->application->{content_type} = $type;
}

=head2 request_method

I<the `request_method` method is used to determine the method used by the
browser to request the specified resource.>

request_method B<arguments>

=over 3

=item L<method|/"$method">

=back

request_method B<usage and syntax>

    $self->request_method;
    
    takes 1 argument
        1st argument  - optional
            $method   - method to match against the current request
            
    example:
    my $self = sweet;
    my $foo = $self->request_method;
    # $foo equals Get, Post, etc
    
    my $foo = $self->request_method('get');
    # foo is 1 if current request method is 'get' or 0 if not

=cut

sub request_method {
    my ($self, $method) = @_;
    if ($method) {
        return lc($ENV{REQUEST_METHOD}) eq lc($method) ? 1 : 0;
    }
    else {
        return $ENV{REQUEST_METHOD};
    }
}

=head2 request

I<the `request` method is a synonym for the `request_method` method.>

=cut

sub request {
    shift->request_method(@_);
}

=head2 push_download

I<the `push_download` method is used to force a browser to prompt it's
user to download the specified content rather than to display it.>

push_download B<arguments>

=over 3

=item L<file_or_data|/"$file_or_data">

=back

push_download B<usage and syntax>

    $self->push_download($file_or_data);
    
    takes 1 argument
        1st argument        - required
            $file_or_data   - file or data to be sent as a download
            
    example:
    my $self = sweet;
    $self->push_download('/tmp/text_file.txt');
    $self->push_download('this is a test');

=cut

sub push_download {
    my ($self, $file) = @_;
    if ($self->{store}->{application}->{mock_run}) {
        $self->mock_data("Attempted to force download file $file.");
        return $self->finish;
    }
    
    my $data;
    my $ext;
    
    if (-e $file && $file) {
        my $name = $file =~ /\/?([\w\.]+)$/ ? $1 : $file;
           $ext  = $name =~ s/(\.\w+)$/$1/ ? $1 : '';
           $data = $self->file('<', $file);
    }
    else {
        $data = $file;
        $ext  = '.txt';
    }
    if ($data) {
        my $ctype = "application/force-download";
        $ctype = "application/pdf"
            if $ext eq ".pdf";
        $ctype = "application/octet-stream"
            if $ext eq ".exe";
        $ctype = "application/zip"
            if $ext eq ".zip";
        $ctype = "application/msword"
            if $ext eq ".doc";
        $ctype = "application/vnd.ms-excel"
            if $ext eq ".xls";
        $ctype = "application/vnd.ms-powerpoint"
            if $ext eq ".ppt";
        $ctype = "image/jpg"
            if $ext eq ".jpg" || $ext eq ".jpeg";
        $ctype = "image/gif"
            if $ext eq ".gif";
        $ctype = "image/png"
            if $ext eq ".png";
        $ctype = "text/plain"
            if $ext eq ".txt";
        $ctype = "text/html"
            if $ext eq ".html" || $ext eq ".htm";

        print("Content-Type: $ctype\n");
        print("Content-Transfer-Encoding: binary\n");
        print("Content-Length: " . length($data) . "\n" );
        print("Content-Disposition: attachment; filename=\"$name\";\n\n");
        print("$data");
        exit;
    }
}

=head2 controller

I<the `controller` method is used to determine the current controller.>

controller B<arguments>

=over 3

=item L<route|/"$route">

=back

controller B<usage and syntax>

    $self->controller;
    
    takes 1 argument
        1st argument  - optional
            $route    - route to append to the current route
            
    example:
    my $self = sweet;
    my $foo = $self->controller;
    # foo equals '/by' if current url path is '/by'
    
    my $foo = $self->controller('/theway');
    # foo equals '/by/theway' if current url path is '/by/theway'

=cut

sub controller {
    my ( $self, $path ) = @_;
    my $controller = $self->uri->{controller}; 
    return "$controller$path" if $controller || $path;
}

=head2 action

I<the `action` method is used to determine the current action being
requested.>

action B<arguments>

no arguments

action B<usage and syntax>

    my $action = $self->action;
    
    takes 0 arguments
            
    example:
    my $action = $self->action;
    # $action equals 'test' if url is http://localhost/do/test
    # $action equals '_index' if url is http://localhost/do/test and
    # controller is Do::Test

=cut

sub action {
    my $self = shift;
    return $self->uri->{action};
}

=head2 uri

I<the `uri` method is can be used to provide access to various parts of the URL
or return the existing/new URL.>

uri B<arguments>

=over 3

=item L<route|/"$routes">

=back

uri B<usage and syntax>

    $self->uri($route);
    
    takes 1 argument
        1st argument  - optional
            $route    - route for use in the creation of the url
            
    example:
    my $self = sweet;
    my $url = $self->uri;
    # if the current url is http://localhost/newapp/by/theway and newapp
    # is a subfolder under the docroot where our app is stored
    # $url->{here} equals http://localhost/newapp/by/theway
    # $url->{root} equals http://localhost/newapp
    
    my $url = $self->uri('/my_friend');
    # $url equals http://localhost/newapp/by/theway/my_friend

=cut

sub uri {
    my ( $self, $path ) = @_;
    return $self->{store}->{application}->{'url'} unless $path;
    $path =~ s/^\///; # remove leading slash for use with root
    return
        $self->cgi->url( -base => 1 )
      . ( $self->{store}->{application}->{'url'}->{'root'} =~ /\/$/
      ? "$self->{store}->{application}->{'url'}->{'root'}$path"
      : "$self->{store}->{application}->{'url'}->{'root'}/$path" );
}

=head2 url

I<the `url` method is a synonym for the `uri` method.>

=cut

sub url { return shift->uri(@_); }

=head2 path

I<the `path` method is used to determine the current root path of the
application or return a new path based on the specified path.>

path B<arguments>

=over 3

=item L<path|/"$path">

=back

path B<usage and syntax>

    $self->path($path);
    
    takes 1 argument
        1st argument  - optional
            $path     - path to append to the root path to be returned
            
    example:
    my $self = sweet;
    my $doc_root = $self->path;
    # $doc_root equals /var/www/site01 if /var/www/site01 is where the
    # application root is
    
    my $path = $self->path('/sweet/sessions');
    # $path equals /var/www/site01/sweet/sessions if /var/www/site01
    # is where the application root is

=cut

sub path {
    my ( $self, $path ) = @_;
    $path =~ s/^\///;
    return $path
      ? $self->{store}->{application}->{'path'} . "/$path"
      : $self->{store}->{application}->{'path'};
}

=head2 cookies

I<the `cookies` method is used to return an array of all currently
existing browser cookies.>

cookies B<arguments>

no arguments

cookies B<usage and syntax>

    my @cookies = $self->cookies;
    
    takes 0 arguments
    
    example:
    my @cookies = $self->cookies;
    # where each @cookies element is a CGI::Cookie object

=cut

sub cookies {
    my $self = shift;
    return
      ref $self->{store}->{application}->{cookie_data} eq "ARRAY"
      ? @{ $self->{store}->{application}->{cookie_data} }
      : ();
}

=head2 flash

I<the `flash` method is used to store and retrieve messages in the session
store for use across requests.>

flash B<arguments>

=over 3

=item L<flash_message|/"$flash_message"> L<flash_type|/"$flash_type">

=back

flash B<usage and syntax>

    $self->flash($message, $type);
    $self->flash($type);
    
    takes 2 arguments
        1st argument  - required
            $message  - display help for a specific command
        2nd argument  - optional
            $type     - type of message to flash [error|info|warn|success]
            
    example:
    my $self = sweet;
    $self->flash('info', 'something weird happened');
    $self->flash('warn', 'something weird happened');
    $self->flash('error', 'something really bad happened');
    $self->flash('success', 'something went terribly right');
    # the above commands all set (flash) session messages in thier
    # respective stores, stores being info, warn, error or success
    
    $self->flash('success', 'something went terribly right');
    # now the flash `success` store is an array and the new entry has
    # been appended
    
    my $success_message = $self->flash('success');
    my $warn_message = $self->flash('warn');
    ...
    # now $success_message, and $warn_message, etc are equal to the last
    # messages stored in thier respective stores and the stores themselves
    # are cleared

=cut

sub flash {
    my ( $self, $type, $message ) = @_;
    my $store;
    
    $store = '_INFO'     if lc($type) eq 'info';
    $store = '_WARN'     if lc($type) eq 'warn';
    $store = '_ERROR'    if lc($type) eq 'error';
    $store = '_SUCCESS'  if lc($type) eq 'success';
    
    # sets a default, backwards compatibility
    if ((lc($type) ne 'info' && lc($type) ne 'warn'
    && lc($type) ne 'error'  && lc($type) ne 'success')
    && ($type && !$store && !$message)) {
        $message = $type;
        $store   = '_INFO';
    }
    
    # prepare for return value
    if (((lc($type) eq 'info' || lc($type) eq 'warn'
    || lc($type) eq 'error'  || lc($type) eq 'success'))
    && ($type && $store && !$message)) {
        $message = '';
    }
    
    if ( defined $message ) {
        my $last_message = $self->session->param( $store );
        
        # append magic if message is not empty
        if ($message ne '' && $last_message) {
            my $arrayref = [];
            if ($last_message) {
                if (ref ($last_message) eq "ARRAY") {
                    push @{$arrayref}, $_ foreach @{$last_message};
                }
                else {
                    push @{$arrayref}, $last_message;
                }
            }
            push @{$arrayref}, $message;
            $message = $arrayref;
        }
        
        $self->session->param( $store => $message );
        $self->session->flush;
        return $message eq '' ? $last_message : $message;
    }
    else {
        return $self->session->param($store);
    }
}

=head2 file

I<the `file` method is used to read and write files under the application
root with ease.>

file B<arguments>

=over 3

=item L<filemode|/"$filemode"> L<filename|/"$filename"> L<data|/"@data">

=back

file B<usage and syntax>

    my $content = $self->file($filemode, $filename, @data);
    
    takes 3 arguments
        1st argument  - required
            $filemode - method used to open a file, e.g. [>>, >, <]
        2nd argument  - required
            $filename - name and path of the file to read or write to
        3rd argument  - optional
            @data     - content to be written to the specified file
            
    example:
    my $self = sweet;
    my $data = $self->file('>', 'new_folder/new_text.txt', 'a test');
    # creates a file new_text.txt in folder new_folder with one line
    
    my $data = $self->file('<', 'new_folder/new_text.txt');
    # read in file content from new_folder/new_text.txt
    
=cut

sub file {
    my ($self, $op, $file, @content) = @_;
    my $output;
    if ($file) {
        if (grep {/^(\<|\>|\>\>)$/} $op) {
            if ($op =~ /\>/) {
                my $bmsk = $content[0] if $content[0] =~ /^\d{3,4}$/;
                if ($bmsk) {
                    $bmsk = ($bmsk !~ /^\d{4}$/ ? oct($bmsk) : $bmsk);
                }
                else {
                    $bmsk = '0777';
                }
                # mkdirs if neccessary
                my @dirs   = ();
                my @path   = split /\//, $file;
                   $file   = pop @path;
                map {
                        push @dirs, $_;
                        mkdir( join('/', @dirs), $bmsk) unless -d
                            join('/', @dirs);
                } @path;
                $output = join "\n", @content;
                open (my $in, $op,
                      (@path ? join('/', @path)."/".$file : $file))
                        || die "Error: $file, $!";
                print $in $output;
                close $in;
                chmod $bmsk, $file;
            }
            else {
                if (-e $file) {
                    open( my $out, $op, $file ) || die "Error: $file, $!";
                    while (<$out>) {
                        $output .= $_;
                    }
                    close $out;
                }
            }
        }
        elsif ($op eq 'x') {
            if (-e $file) {
                $output = $self->file('<', $file);
                unlink $file;
            }
        }
    }
    return $output;
}

=head2 upload

I<the `upload` method is used to simplify uploading files from clients to
the application server space.>

upload B<arguments>

=over 3

=item L<upload_field|/"$upload_field"> L<path|/"$path">
L<filename|/"$filename">

=back

upload B<usage and syntax>

    my $filename = $self->upload($upload_field, $path, $filename);
    
    takes 3 arguments
        1st argument      - required
            $upload_field - name of the field input element
        2nd argument      - required
            $path         - path to folder where file will be saved
        3rd argument      - optional
            $filename     - name of file to be created
            
    example:
    my $self = sweet;
    $self->upload('form_field', '/tmp/uploads');
    # uploads a file from the client to the server using localtime to 
    # create the filename

=cut

sub upload {
    my ($self, $upload_field, $location, $filename) = @_;
    my $fh = $self->cgi->upload($upload_field);
    unless ($filename) {
        $filename =
            $self->param($upload_field) =~ /([\w\.]+)$/ ?
                $1 : time();
    }
    $location =~ s/\/$//;
    $location = '.' unless $location;
    if ( not -e "$location/$filename" ) {
        open (OUTFILE, ">$location/$filename");
        while (<$fh>) {
              print OUTFILE $_;
        }
        close OUTFILE;
        return $filename;
    }
    else {
        return 0;
    }
}

=head2 html

I<the `html` method is used to store data at various stages of the request
and return that data for output.>

html B<arguments>

=over 3

=item L<data|/"@data">

=back

html B<usage and syntax>

    my @data = $self->html;
    
    takes 1 argument
        1st argument  - optional
            @data     - data to be stored for output
            
    example:
    my $self  =sweet;
    $self->html('save this for me', 'oh yeah, and this too');
    my @data = $self->html;
    # @data equals ['save this for me', 'oh yeah, and this too']
    my @data = $self->html;
    # @data equals [] because $self->html (no args) clears the store
    
    # Note! This method is called automatically and rendered if no
    # template is specified.

=cut

sub html {
    my ( $self, @html ) = @_;
    if (@html) {
        my @existing_html =
          $self->{store}->{application}->{html_content}
          ? @{ $self->{store}->{application}->{html_content} }
          : ();
        push @existing_html, @html;
        $self->{store}->{application}->{html_content} = \@existing_html;
        return;
    }
    else {
        if ( $self->{store}->{application}->{html_content} ) {
            my @content = @{ $self->{store}->{application}->{html_content} };
            $self->{store}->{application}->{html_content} = [];
            return \@content;
        }
    }
}

=head2 debug

I<the `debug` method is used to store data to be output at the command-line
for debugging purposes.>

debug B<arguments>

=over 3

=item L<data|/"@data">

=back

debug B<usage and syntax>

    $self->debug;
    
    takes 1 argument
        1st argument  - optional
            @data     - data to be stored for output
            
    example:
    my $self  =sweet;
    $self->debug('something happened here', "\$var has a val of $var");
    my @data = $self->data;
    # @data equals ['something happened here', "$var has a val of blah"]
    my @data = $self->data;
    # @data equals [] because $self->data (no args) clears the store

=cut

sub debug {
    my ( $self, @debug ) = @_;
    if (@debug) {
        my @existing_debug =
          $self->{store}->{application}->{debug_content}
          ? @{ $self->{store}->{application}->{debug_content} }
          : ();
        my ( $package, $filename, $line ) = caller;
        my $count = (@existing_debug+1);
        @debug =
          map { $count . ". $_ at $package [$filename], on line $line." }
          @debug;
        push @existing_debug, @debug;
        $self->{store}->{application}->{debug_content} = \@existing_debug;
        return;
    }
    else {
        if ( $self->{store}->{application}->{debug_content} ) {
            my @content = @{ $self->{store}->{application}->{debug_content} };
            $self->{store}->{application}->{debug_content} = [];
            return \@content;
        }
    }
}

=head2 output

I<the `output` method is used to render stored data to the browser or
command-line.>

output B<arguments>

=over 3

=item L<output_what|/"$output_what"> L<output_where|/"$output_where">
L<seperator|/"$seperator">

=back

output B<usage and syntax>

    $self->output($output_what, $output_where, $seperator);
    
    takes 3 arguments
        1st argument     - required
            $output_what - what data store to render [html|debug]
        2nd argument     - optional
            $output_where- where to render content [web|cli]
        3rd argument     - optional
            $seperator   - printable line seperator
            
    example:
    my $self = sweet;
    $self->output('html'); # print html store to browser using <br/>
    $self->output('debug'); # print debug store to browser using <br/>
    
    $self->output('html', 'cli');
    # print html store to the command-line using \n
    
    $self->output('debug', 'cli', ',');
    # print debug store to the command-line using `,` as a seperator

=cut

sub output {
    my ( $self, $what, $where, $using ) = @_;
    if ($what eq 'debug') {
        if ($where eq 'cli') {
            my $input = $self->debug;
            my @output = $input ? @{$input} : ();
            my $seperator = defined $using ? $using : "\n";
            print join( $seperator, @output );
            exit;
        }
        else {
            my $input = $self->debug;
            my @output = $input ? @{$input} : ();
            my $seperator = defined $using ? $using : "<br/>";
            $self->start();
            print join( $seperator, @output );
            exit;
        }
    }
    else {
        if ($where eq 'cli') {
            my $input = $self->html;
            my @output = $input ? @{$input} : ();
            my $seperator = defined $using ? $using : "\n";
            print join( $seperator, @output );
            exit;
        }
        else {
            my $input = $self->html;
            my @output = $input ? @{$input} : ();
            my $seperator = defined $using ? $using : "<br/>";
            $self->start();
            print join( $seperator, @output );
            exit;
        }
    }
}

=head2 plug

I<the `plug` method is used to create accessors to add-on module classes.>

plug B<arguments>

=over 3

=item L<accessor_name|/"$accessor_name"> L<code_ref|/"$code_ref">

=back

plug B<usage and syntax>

    $self->plug($accessor_name, $code_ref);
    
    takes 2 argument
        1st argument        - required
            $accessor_name  - name to be used in the app to access the code
        2ns argument        - required
            $code_ref       - code that instantiates an object of a class
            
    example:
    my $self = sweet;
    $self->plug('cgi', sub {
        shift;
        CGI->new(@_);
    });
    
    # elsewhere in the code
    $self->cgi->param('foo'); # etc
    $self->cgi->url_param('bar'); # same instance, different method call
    
    $self->unplug('cgi')->cgi->param('foo'); # new instance

=cut

sub plug {
    my ( $self, $name, $init ) = @_;
    if ( $name && $init ) {
        no warnings 'redefine';
        no strict 'refs';
        my $routine = ref($self) . "::$name";
        if ( ref $init eq "CODE" ) {
            *{$routine} = sub {
                $self->{".$name"} = $init->(@_) unless $self->{".$name"};
                return $self->{".$name"};
            };
        }
        else {
            *{$routine} = sub {
                $self->{".$name"} = $init unless $self->{".$name"};
                return $self->{".$name"};
            };
        }
    }
}

=head2 unplug

I<the `unplug` method is used to delete the existing class object
instance so a new one can be created.>

unplug B<arguments>

=over 3

=item L<accessor_name|/"$accessor_name">

=back

unplug B<usage and syntax>

    $self = $self->unplug($accessor_name);
    
    takes 1 argument
        1st argument       - required
            $accessor_name - name to be used in the app to access the code
            
    example:
    my $self = sweet;
    $self->unplug('cgi');
    # creates a new instance of the CGI class object the next time
    # $self->cgi is called.

=cut

sub unplug {
    my ( $self, $name ) = @_;
    delete $self->{".$name"};
    return $self;
}

=head2 routes

I<the `routes` method is used to define custom routes, routing urls to
controllers and actions.>

routes B<arguments>

=over 3

=item L<actions|/"\%actions">

=back

routes B<usage and syntax>

    $self = $self->routes($actions);
    
    takes 1 argument
        1st argument  - required
            \%actions - hashref of urls and coderef
            
    example:
    my $self = sweet;
    $self->routes({
        '/' => sub {
            my $s = shift;
            $s->html('Im an index page.');
        },
        '/about' => sub {
            my $s = shift;
            $s->html('Im an about us page');
        }
    });

=cut

sub routes {
    my ( $self, $routes ) = @_;
    map {
        my $url = $_;
        $url =~ s/\/$// if $url =~ /\/$/ && length($url) > 1;
        $self->application->{actions}->{$url} = $routes->{$_};
    } keys %{$routes};
    return $self;
}

=head2 param

I<the `param` method is used to access get, post and session parameters.>

param B<arguments>

=over 3

=item L<param_name|/"$param_name"> L<param_type|/"$param_type">
L<param_value|/"$param_value">

=back

param B<usage and syntax>

    my $value = $self->param($param_name, $param_type);
    
    takes 2 argument
        1st argument    - required
            $param_name - name of the get, post or session parameter
        2nd argument    - optional
            $param_type - type of parameter
            
    example:
    my $self = sweet;
    my $value = $self->param('foo');
    my $value = $self->param('foo', 'get');
    
    my $new = $self->param('foo', 'session', 'something new');
    # sets value as well
    

=cut

sub param {
    my ( $self, $name, $type, $value ) = @_;
    
    if ($value) {
        $self->cgi->param($name, $value)
            if $type eq 'get' or $type eq 'post';
        $self->session->param($name, $value)
            if $type eq 'session';
    }
    
    if ( $name && $type ) {
        return (
                $type eq 'get' ? $self->cgi->url_param($name)
            : ( $type eq 'post' ? $self->cgi->param($name)
            : ( $type eq 'session' ? $self->session->param($name) : '' ) )
        );
    }
    elsif ( $name && !$type ) {
        return $self->cgi->url_param($name) if $self->cgi->url_param($name);
        return $self->cgi->param($name) if $self->cgi->param($name);
        return $self->session->param($name) if $self->session->param($name);
        return $self->application->{action_params}->{$self->controller}->{$name} if
        defined $self->application->{action_params}->{$self->controller}->{$name};
    }
    else {
        return 0;
    }
}

=head2 sweet

I<the `sweet` method is shorthand for instantiating a new SweetPea object.>

sweet B<arguments>

=over 3

=item L<options|/"\%options">

=back

sweet B<usage and syntax>

    $self = sweet;
    
    takes 1 argument
        1st argument  - optional
            \%options - sweetpea runtime options
            
    example:
    my $s = sweet;
    my $s = sweet({ session_folder => '/tmp' });

=cut

sub sweet {
    return SweetPea->new(@_);
}

=head1 VARIABLE LEGEND

=head2 \%actions

    my $routes = {
        '/url_path' => sub {
            $sweetpea_object = shift;
            ...
        },
        'other_url_path' => sub {
            $sweetpea_object = shift;
            ...
        }
    };
    
=head2 \%options

    my $sweetpea_runtime_options = {
        local_session => 1,
        session_folder => '/tmp/site1'
    };

=head2 $route

    my $route = '/'; # index/default page
    my $route = '/contact'; # good
    my $route = 'contact'; # bad

=head2 $self

    my $self = sweet; # a SweetPea object
    my $self = SweetPea->new;

=head2 @data

    my @data = qw(this is a test);
    # a simple array of data to be stored

=head2 $url

    my $url = '/path/under/application/root/'; # good
    my $url = 'http://www.somesite.com/path/under/blah'; #bad

=head2 $content_type

    my $content_type = 'text/html';
    my $content_type = 'text/plain';
    # etc

=head2 $method

    my $method = 'get'; # valid request method
    my $method = 'post'; # valid request method
    my $method = 'put'; # valid request method
    # etc

=head2 $file_or_data

    my $file_or_data = 'c:\tmp\file.txt'; # cool
    my $file_or_data = '/tmp/file.txt'; # good
    my $file_or_data = 'this is some content'; # works
    
    my $file_or_data = sweet->file('<', 'file.txt'); #bad
    my $file_or_data = join "\n", sweet->file('<', 'file.txt'); #better

=head2 $path

    my $path = 'c:\tmp\file.txt'; # bad
    my $path = '/tmp/file.txt'; # bad
    my $path = '/under/application/root'; # yes, very nice
    my $path = 'under/application/root'; # works as well

=head2 $flash_message

    my $flash_message = 'anything you need to convey to the user';

=head2 $flash_type

    my $flash_type = 'info'; #good
    my $flash_type = 'warn'; #good
    my $flash_type = 'error'; #good
    my $flash_type = 'success'; #good
    my $flash_type = 'blah'; #bad

=head2 $filemode

    my $filemode = 0666; # good
    my $filemode = 0777; #good
    my $filemode = 755; # bad
    my $filemode = 'catdog'; #bad

=head2 $filename

    my $filename = 'c:\tmp\file.txt'; # cool
    my $filename = '/tmp/file.txt'; # good

=head2 $output_what

    my $output_what = 'html'; # good
    my $output_what = 'debug'; # good
    my $output_what = 'textile'; # bad

=head2 $output_where

    my $output_where = 'web'; # good
    my $output_where = 'cli'; # bad

=head2 $seperator

    my $seperator = 'whatever'; # works, makes no sense though
    my $seperator = ',';
    my $seperator = "\n";
    my $seperator = "\r\n"; # windows
    my $seperator = "\t";

=head2 $accessor_name

    my $accessor_name = 'math'; # good
    my $accessor_name = 'math_calc'; # good
    my $accessor_name = '_math_calc'; # ok
    
    my $accessor_name = '132'; # bad
    my $accessor_name = 'math-calc'; # very bad

=head2 $code_ref

    my $code_ref = sub {
        my $sweetpea = shift; # always the first object
        ...
    };

=head2 $param_name

    my $param_name = 'whatever';

=head2 $param_type

    my $param_type = 'get'; # good
    my $param_type = 'post'; # good
    my $param_type = 'session'; # good
    
    my $param_type = 'csv'; # bad

=head2 $param_value

    my $param_value = 'whatever';

=cut

1; # End of SweetPea
