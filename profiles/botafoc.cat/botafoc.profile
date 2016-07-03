<?php

use Drupal\Core\Config\StorageComparer;
use Drupal\Core\Config\ConfigImporter;
use Drupal\Core\Config\ConfigImporterException;
use Drupal\Core\Language\LanguageManager;
use Drupal\Core\Language\LanguageInterface;
use Drupal\language\Entity\ConfigurableLanguage;

include_once __DIR__ . '/src/Form/SelectLanguagesForm.php';
include_once __DIR__ . '/src/Form/SelectConfigurationForm.php';

function botafoc_install_tasks_alter(&$tasks, $install_state) {
  $all_tasks = $tasks;
  $tasks = array();

  // Define first task Select languages
  $tasks['install_select_languages'] = array(
    'display_name' => t('Select languages'),
    'run' => INSTALL_TASK_RUN_IF_REACHED,
  );

  // Define second task Select configuration
  $tasks['install_select_configuration'] = array(
    'display_name' => t('Select configuration'),
  );

  // Added task after task key
  foreach($all_tasks as $key => $value) {
    $tasks[$key] = $value;

    // Is required to install_configuration executed after install_import_translations.
    if ($key == 'install_import_translations') {
      $tasks['install_initial_configuration'] = array(
        'display_name' => t('Install configuration'),
      );
    }

    // Is required to install_configuration executed after install_import_translations.
    if ($key == 'install_finished') {
      $tasks['install_last_configuration'] = array(
        'display_name' => t('Last configuration'),
      );
    }
  }

  // Disable tasks
  $tasks['install_select_language'] = array(
    'display' => 0,
  );
}

function install_select_languages(&$install_state) {
  // Find all available translation files.
  $files = install_find_translations();
  $install_state['translations'] += $files;

  // If a valid language code is set, continue with the next installation step.
  // When translations from the localization server are used, any language code
  // is accepted because the standard language list is kept in sync with the
  // languages available at http://localize.drupal.org.
  // When files from the translation directory are used, we only accept
  // languages for which a file is available.
  if (!empty($install_state['parameters']['langcode'])) {
    $standard_languages = LanguageManager::getStandardLanguageList();
    $langcode = $install_state['parameters']['langcode'];
    if ($langcode == 'en' || isset($files[$langcode]) || isset($standard_languages[$langcode])) {
      $install_state['parameters']['langcode'] = $langcode;
      return;
    }
  }

  if (empty($install_state['parameters']['langcode'])) {
    // If we are performing an interactive installation, we display a form to
    // select a right language. If no translation files were found in the
    // translations directory, the form shows a list of standard languages. If
    // translation files were found the form shows a select list of the
    // corresponding languages to choose from.
    if ($install_state['interactive']) {
      return install_get_form('Drupal\botafoc\Form\SelectLanguagesForm', $install_state);
    }
    // If we are performing a non-interactive installation. If only one language
    // (English) is available, assume the user knows what he is doing. Otherwise
    // throw an error.
    else {
      if (count($files) == 1) {
        $install_state['parameters']['langcode'] = current(array_keys($files));
        return;
      }
      else {
        throw new InstallerException(t('You must select a language to continue the installation.'));
      }
    }
  }
}

function install_select_configuration(&$install_state) {
  if (empty($install_state['parameters']['configuration'])) {
    return install_get_form('Drupal\botafoc\Form\SelectConfigurationForm', $install_state);
  }
}

function install_initial_configuration(&$install_state) {
  if (!empty($_GET['langcodes'])) {
    $langcodes = $_GET['langcodes'];

    foreach($langcodes as $key => $value) {
      if ($key != $_GET['langcode']) {
        ConfigurableLanguage::createFromLangcode($key)->save();
      }
    }
  }
}

function install_last_configuration(&$install_state) {
  if(!empty($_GET['langcode'])) {
    $user = \Drupal\user\Entity\User::load(1);
    $user->set("preferred_langcode", $_GET['langcode']);
    $user->set("preferred_admin_langcode", $_GET['langcode']);
    $user->save();
  }
}

function botafoc_form_alter(&$form, \Drupal\Core\Form\FormStateInterface $form_state, $form_id) {
  if ($form_id == 'install_configure_form') {
    $form['site_information']['#type'] = 'details';
    $form['site_information']['#open'] = TRUE;
    $form['admin_account']['#type'] = 'details';
    $form['admin_account']['#open'] = TRUE;
    $form['regional_settings']['#type'] = 'details';
    $form['update_notifications']['#type'] = 'details';
  }
}
