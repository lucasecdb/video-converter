import { Snackbar } from '@lucasecdb/rmdc'
import React, { useCallback, useEffect, useState } from 'react'

import { notificationState } from '../notification/index'
import { NotificationEvent } from '../notification/state'

const NotificationToasts: React.FunctionComponent = () => {
  const [notificationEvents, setNotifications] = useState<NotificationEvent[]>(
    []
  )

  const handleNotificationRemove = useCallback((id: string) => {
    setNotifications(prev => prev.filter(event => event.id !== id))
  }, [])

  useEffect(
    () =>
      notificationState.onNotification(event => {
        setNotifications(prev => [...prev, event])
      }),
    []
  )

  useEffect(
    () =>
      notificationState.onNotificationRemoved(({ id }) => {
        handleNotificationRemove(id)
      }),
    [handleNotificationRemove]
  )

  return (
    <>
      {notificationEvents.map(event => {
        const {
          id,
          notification: {
            onAction,
            timeoutMs,
            actionText,
            message,
            options = {},
          },
        } = event
        const {
          stacked = false,
          leading = true,
          closeOnEscape = false,
        } = options

        const translatedActionText = actionText || ''

        return (
          <Snackbar
            key={id}
            leading={leading}
            stacked={stacked}
            closeOnEscape={closeOnEscape}
            message={message}
            actionText={translatedActionText}
            timeoutMs={timeoutMs}
            onClose={action => {
              handleNotificationRemove(id)

              if (action === 'action') {
                onAction && onAction()
              }
            }}
          />
        )
      })}
    </>
  )
}

export default NotificationToasts
