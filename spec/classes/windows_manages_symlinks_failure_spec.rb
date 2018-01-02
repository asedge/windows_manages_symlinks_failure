require 'spec_helper'

describe 'windows_manages_symlinks_failure' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
			let(:facts) { os_facts }

      files = %w( C:/Windows/Temp/foo C:/Windows/Temp/bar )

      it { should compile.with_all_deps }
      it { should contain_class('windows_manages_symlinks_failure') }
      files.each do |file|
        it { should contain_file(file) }
      end
    end
  end
end
