require 'rspec-puppet'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

module RSpec::Puppet::Support
    def load_catalogue(type, exported = false, manifest_opts = {})
      with_vardir do
        node_name = nodename(type)

        hiera_config_value = self.respond_to?(:hiera_config) ? hiera_config : nil
        hiera_data_value = self.respond_to?(:hiera_data) ? hiera_data : nil

        build_facts = facts_hash(node_name)
        catalogue = build_catalog(node_name, build_facts, trusted_facts_hash(node_name), hiera_config_value,
                                  build_code(type, manifest_opts), exported, node_params_hash, hiera_data_value)

        test_module = type == :host ? nil : class_name.split('::').first
        if type == :define
          RSpec::Puppet::Coverage.add_filter(class_name, title)
        else
          RSpec::Puppet::Coverage.add_filter(type.to_s, class_name)
        end
        RSpec::Puppet::Coverage.add_from_catalog(catalogue, test_module)

        ['operatingsystem', 'osfamily'].each do |os_fact|
          if build_facts.key?(os_fact)
            if build_facts[os_fact].to_s.downcase == 'windows'
              Puppet::Util::Platform.pretend_to_be :windows
            else
              Puppet::Util::Platform.pretend_to_be :posix
            end
          end
        end

        catalogue
      end
    end

    def build_catalog(*args)
      @@cache.get(*args) do |*args|
        build_catalog_without_cache(*args)
      end
    end

    def build_catalog_without_cache(nodename, facts_val, trusted_facts_val, hiera_config_val, code, exported, node_params, *_)

      # If we're going to rebuild the catalog, we should clear the cached instance
      # of Hiera that Puppet is using.  This opens the possibility of the catalog
      # now being rebuilt against a differently configured Hiera (i.e. :hiera_config
      # set differently in one example group vs. another).
      # It would be nice if Puppet offered a public API for invalidating their
      # cached instance of Hiera, but que sera sera.  We will go directly against
      # the implementation out of absolute necessity.
      HieraPuppet.instance_variable_set('@hiera', nil) if defined? HieraPuppet

      Puppet[:code] = code

      stub_facts! facts_val

      Puppet::Type.eachtype { |type| type.defaultprovider = nil }

      node_facts = Puppet::Node::Facts.new(nodename, facts_val.dup)
      node_params = facts_val.merge(node_params)

      node_obj = Puppet::Node.new(nodename, { :parameters => node_params, :facts => node_facts })

      if Puppet::Util::Package.versioncmp(Puppet.version, '4.3.0') >= 0
        Puppet.push_context(
          {
            :trusted_information => Puppet::Context::TrustedInformation.new('remote', nodename, trusted_facts_val)
          },
          "Context for spec trusted hash"
        )
      end

      adapter.catalog(node_obj, exported)
    end

    def stub_facts!(facts)
      Puppet.settings[:autosign] = false
      Facter.clear
      facts.each { |k, v| Facter.add(k) { setcode { v } } }
    end
end

# Stub out Puppet::Util::Windows::Security.supports_acl? if it has been
# defined. This check only makes sense when applying the catalogue to a host
# and so can be safely stubbed out for unit testing.
Puppet::Type.type(:file).provide(:windows).class_eval do
  old_supports_acl = instance_method(:supports_acl?) if respond_to?(:supports_acl?)

  def supports_acl?(path)
    if RSpec::Puppet.rspec_puppet_example?
      true
    else
      old_supports_acl.bind(self).call(value)
    end
  end
end
