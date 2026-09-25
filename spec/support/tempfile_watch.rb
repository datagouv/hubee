# frozen_string_literal: true

module TempfileWatch
  # Le chemin de chaque fichier temporaire créé, pour vérifier qu'il n'a pas survécu.
  def watch_tempfile_paths
    paths = []
    expect(Tempfile).to receive(:new).and_wrap_original do |new, *args, **options|
      new.call(*args, **options).tap { |file| paths << file.path }
    end
    paths
  end
end

RSpec.configure do |config|
  config.include TempfileWatch
end
