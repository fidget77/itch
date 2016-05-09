#!/usr/bin/env ruby
# pushes an updated itch PKGBUILD to AUR

require_relative 'common'

module Itch
  def Itch.ci_deploy_aur
    say "Cloning repo..."
    ✓ sh "git clone ssh+git://aur@aur.archlinux.org/#{app_name}.git aur-stage"

    FileUtils.cp "release/templates/aur.itch.install", "aur-stage/#{app_name}.install"

    say "Generating PKGBUILD..."
    rel = 1
    begin
      # increment release number if versions match
      opk = File.read "aur-stage/PKGBUILD"
      oldver = /pkgver=(.+)/.match(opk)[1]
      oldrel = /pkgrel=(.+)/.match(opk)[1]
      if oldver == build_version
        rel = oldrel.to_i + 1
      end
    rescue => e
      say "Couldn't read old pkgbuild: #{e.inspect}"
    end

    pk = File.read "release/templates/PKGBUILD.in"
    pk = pk.gsub "{{CI_APPNAME}}", app_name
    pk = pk.gsub "{{CI_VERSION}}", build_version
    pk = pk.gsub "{{CI_REL}}", rel

    File.write "aur-stage/PKGBUILD", pk

    say "Updating checksums..."
    ✓ sh %Q{updpkgsums}

    say "Validating PKGBUILD..."
    ✓ sh %Q{namcap -i PKGBUILD}

    say "Building package locally..."
    ✓ sh %Q{makepkg --syncdeps --force --needed --noconfirm}

    say "Validating built package..."
    ✓ sh %Q{namcap "$pkgname-$NEWVERSION-$pkgrel-$(uname -m).pkg.tar.xz}

    say "Updating .SRCINFO..."
    ✓ sh %Q{mksrcinfo}

    say "Pushing to AUR..."
    ✓ sh %Q{git add PKGBUILD .SRCINFO}
    ✓ sh %Q{git commit -m ":arrow_up: #{build_tag}"}
    ✓ sh %Q{git push}
  end
end

Itch.ci_deploy_aur