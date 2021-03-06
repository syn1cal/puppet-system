Puppet::Parser::Functions.newfunction(:system_create_resources, arity: -3, doc: <<-'ENDHEREDOC') do |args|
    Converts a hash into a set of resources and adds them to the catalog.

    This function takes two mandatory arguments: a resource type, and a hash describing
    a set of resources. The hash should be in the form `{title => {parameters} }`:

        # A hash of user resources:
        $myusers = {
          'nick' => { uid    => '1330',
                      group  => allstaff,
                      groups => ['developers', 'operations', 'release'], }
          'dan'  => { uid    => '1308',
                      group  => allstaff,
                      groups => ['developers', 'prosvc', 'release'], }
        }

        system_create_resources(user, $myusers)

    A third, optional parameter may be given, also as a hash:

        $defaults = {
          'ensure'   => present,
          'provider' => 'ldap',
        }

        system_create_resources(user, $myusers, $defaults)

    The values given on the third argument are added to the parameters of each resource
    present in the set given on the second argument. If a parameter is present on both
    the second and third arguments, the one on the second argument takes precedence.

    This function can be used to create defined resources and classes, as well
    as native resources.

    Virtual and Exported resources may be created by prefixing the type name
    with @ or @@ respectively.  For example, the $myusers hash may be exported
    in the following manner:

        system_create_resources("@@user", $myusers)

    The $myusers may be declared as virtual resources using:

        system_create_resources("@user", $myusers)

  ENDHEREDOC
  raise ArgumentError, "system_create_resources(): wrong number of arguments (#{args.length}; must be 2 or 3)" if args.length > 3

  # figure out what kind of resource we are
  type_of_resource = nil
  type_name = args[0].downcase
  type_exported, type_virtual = false
  if type_name.start_with? '@@'
    type_name = type_name[2..-1]
    type_exported = true
  elsif type_name.start_with? '@'
    type_name = type_name[1..-1]
    type_virtual = true
  end
  if type_name == 'class'
    type_of_resource = :class
  elsif resource == Puppet::Type.type(type_name.to_sym)
    type_of_resource = :type
  elsif resource == find_definition(type_name.downcase)
    type_of_resource = :define
  else
    raise ArgumentError, "could not create resource of unknown type #{type_name}"
  end
  # iterate through the resources to create
  defaults = args[2] || {}
  args[1].each do |title, params|
    params = Puppet::Util.symbolizehash(defaults.merge(params))
    raise ArgumentError, 'params should not contain title' if params[:title]
    case type_of_resource
    # JJM The only difference between a type and a define is the call to instantiate_resource
    # for a defined type.
    when :type, :define
      p_resource = Puppet::Parser::Resource.new(type_name, title, scope: self, source: resource)
      p_resource.virtual = type_virtual
      p_resource.exported = type_exported
      { name: title }.merge(params).each do |k, v|
        p_resource.set_parameter(k, v)
      end
      if type_of_resource == :define
        resource.instantiate_resource(self, p_resource)
      end
      compiler.add_resource(self, p_resource)
    when :class
      klass = find_hostclass(title)
      raise ArgumentError, "could not find hostclass #{title}" unless klass
      klass.ensure_in_catalog(self, params)
      compiler.catalog.add_class(title)
    end
  end
end
