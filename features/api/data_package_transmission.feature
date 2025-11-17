# frozen_string_literal: true
Feature: Data Package Transmission
  As a data producer
  I want to create and transmit data packages
  So that subscribers receive notifications

  Background:
    Given an organization "DILA" with SIRET "13002526500013"
    And a data stream "CertDC" owned by "DILA"
    And an organization "Commune Lyon" with SIRET "21690123400019"
    And "Commune Lyon" is subscribed to "CertDC" with read permission

  Scenario: Successful transmission with notifications
    When I create a data package for "CertDC" from "DILA" targeting SIRET "21690123400019"
    Then the data package is created in "draft" state
    When I transmit the data package
    Then the transmission succeeds
    And the data package state is "transmitted"
    And a notification is created for "Commune Lyon"
    And the notification is not yet acknowledged

  Scenario: Transmission to multiple recipients
    Given an organization "Mairie Paris" with SIRET "21750001600019"
    And "Mairie Paris" is subscribed to "CertDC" with read permission
    When I create a data package for "CertDC" from "DILA" targeting SIRETs:
      | siret          |
      | 21690123400019 |
      | 21750001600019 |
    And I transmit the data package
    Then the transmission succeeds
    And the data package state is "transmitted"
    And 2 notifications are created
    And a notification is created for "Commune Lyon"
    And a notification is created for "Mairie Paris"

  Scenario: Transmission fails without recipients
    When I create a data package for "CertDC" from "DILA" targeting SIRET "99999999999999"
    And I transmit the data package
    Then the transmission fails with "no recipients" error
    And the data package state is "draft"
    And no notifications are created
