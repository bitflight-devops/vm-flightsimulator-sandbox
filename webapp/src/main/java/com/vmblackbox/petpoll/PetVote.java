package com.vmblackbox.petpoll;

/**
 * Immutable value object representing a single row from the {@code votes} table.
 *
 * @param petName the pet name (primary key in the database)
 * @param count   the current vote tally
 */
public record PetVote(String petName, int count) {}
