puts "\n- Environment: #{Rails.env}"
puts " |-- Executando fixtures\n"

Rake::Task['db:fixtures:load'].invoke if Rails.env.in?(['development', 'test'])

## Setup Production
if Rails.env == 'production'
  ## criar usuario padrao

  ## rodar fixtures:
    ## profiles
    ## resources
    ## permissions_resources
    ## menus
    ## permissions_menus

  ## verificar criacao dos IDS

  # YAML::load(File.open('test/fixtures/profiles.yml')).each {|p| Profile.find_or_create_by_id(p.last) }
  # YAML::load(File.open('test/fixtures/resources.yml')).each {|r| Resource.find_or_create_by_id(r.last) }
  # YAML::load(File.open('test/fixtures/permissions_resources.yml')).each {|pr| PermissionsResource.find_or_create_by_profile_id_and_resource_id(pr.last) }
  # YAML::load(File.open('test/fixtures/menus.yml')).each {|m| Menu.find_or_create_by_id(m.last) }
  # YAML::load(File.open('test/fixtures/permissions_menus.yml')).each {|pm| PermissionsMenu.find_or_create_by_profile_id_and_menu_id(pm.last) }
end

puts " |-- Fixtures ok\n\n"
