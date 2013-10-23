package MakeMkv;

use Carp;
use Class::Struct;

################################################################################

my %FIELDS = 
(
    "MakeMkv::makemkvcon" => "makemkvcon"         ,
    "MakeMkv::cmd"        => "--directio=true"    ,
    "MakeMkv::source"     => "disc:1"             ,
    "MakeMkv::titles"     => []                   ,
);

sub new
{
    my $invocant   = shift;
    my $class      = ref($invocant) || $invocant;
    my $self       = {%FIELDS, @_};

    bless  $self, $class;
    return $self;
}

sub info
{
    my $self = shift;
    my $output;

    if (! @_)
    {
        my $mkvcmd = join(" ",
        (
            $self->makemkvcon(),
            $self->cmd()       ,
            "-r"               ,
            "info"             ,
            $self->source()    ,
        ));

        print "::$mkvcmd\n";
        $output = `$mkvcmd 2>&1` or die "Makemkv failed: $!";
    }
    else
    {
        my $file = shift;
        $output = do 
        {
            local $/ = undef;
            open my $FILE, "<", $file
                or die "could not open $file: $!";
            <$FILE>;
        };
    }

    my @parts = split(/\r?\n/, $output);
    foreach (@parts) 
    {
        if ($_ =~ m/^TINFO:(.+)$/) 
        {
            $self->addTitleInfo($1);
        } 
    }
}

sub mkv
{
    my $self        = shift;
    my $title       = shift;
    my $destination = shift;

    my $mkvcmd = join(" ",
    (
        $self->makemkvcon(),
        $self->cmd()       ,
        "mkv"              ,
        $self->source()    ,
        "$title"           ,
        "\"$destination\"" ,
        "--cache=1024"     ,
        "--noscan"         ,
    ));

    print "::$mkvcmd\n";
    system($mkvcmd); 
}

sub getTitles
{
    my $self = shift;
    return $self->{MakeMkv::titles};
}

sub addTitleInfo
{
    my $self   = shift;
    my $tinfo  = shift; 

    if ($tinfo =~ m/^(\d+),(\d+),(\d+),\"(.+)\"$/)
    {
        my $id    = $1;
        my $code  = $2;
        my $value = $4;

        if (! exists($self->{MakeMkv::titles}[$id]))
        {
            my $title = Title->new();

            $title->name("noname");
            $title->titleNum($id);
            $title->chapters("0");
            $title->playlist("");

            $self->{MakeMkv::titles}[$id] = $title;
        }

        if ($code eq "2") 
        { 
            $self->{MakeMkv::titles}[$id]->name($value) 
        }
        elsif ($code eq "8" )
        {
            $self->{MakeMkv::titles}[$id]->chapters($value) 
        }
        elsif ($code eq "9" ) 
        {
            $self->{MakeMkv::titles}[$id]->duration($value);
            $self->{MakeMkv::titles}[$id]->durationSec(
                durationToSeconds($value));
        }
        elsif ($code eq "10") {$self->{MakeMkv::titles}[$id]->size($value)     }
        elsif ($code eq "11") {$self->{MakeMkv::titles}[$id]->sizeBytes($value)}
        elsif ($code eq "16") {$self->{MakeMkv::titles}[$id]->playlist($value) }
        elsif ($code eq "27") {$self->{MakeMkv::titles}[$id]->mkvFile($value)  }
    }
}

sub AUTOLOAD
{
    my $self = shift;
    croak "$self not an object" unless ref($self);

    my $name = our $AUTOLOAD;
    return if $name =~ /::DESTROY$/;

    croak "Can't access '$name' field in $self"
        unless (exists $self->{$name});

    if (@_) { return $self->{$name} = shift; }
    else    { return $self->{$name}; }
}

sub durationToSeconds
{
    my $duration = shift;
    my ($h, $m, $s) = split(':', $duration);

    return ($h * 60 * 60) + ($m * 60) + $s;
}

################################################################################

struct Title => 
{
    titleNum    => '$',
    name        => '$',
    chapters    => '$',
    duration    => '$',
    durationSec => '$',
    size        => '$',
    sizeBytes   => '$',
    playlist    => '$',
    mkvFile     => '$',
};

1;
