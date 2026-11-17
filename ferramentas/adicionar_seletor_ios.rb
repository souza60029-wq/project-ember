# Adiciona ios/EmberSeletor.m ao projeto Xcode exportado pelo Godot e liga o PhotosUI.
# Uso: ruby ferramentas/adicionar_seletor_ios.rb build/ios/project.xcodeproj
require 'xcodeproj'
require 'fileutils'

caminho = ARGV[0] or abort('uso: adicionar_seletor_ios.rb <projeto.xcodeproj>')
proj = Xcodeproj::Project.open(caminho)
pasta = File.dirname(File.expand_path(caminho))
FileUtils.cp('ios/EmberSeletor.m', File.join(pasta, 'EmberSeletor.m'))

alvo = proj.targets.find { |t| t.name == 'project' } || proj.targets.first
abort('nenhum target encontrado') if alvo.nil?
ref = proj.main_group.new_reference('EmberSeletor.m')
alvo.source_build_phase.add_file_reference(ref)
arq = alvo.source_build_phase.files.find { |f| f.file_ref == ref }
arq.settings = { 'COMPILER_FLAGS' => '-fobjc-arc' }
alvo.add_system_framework('PhotosUI')
proj.save
puts "EmberSeletor.m adicionado ao target #{alvo.name}"
