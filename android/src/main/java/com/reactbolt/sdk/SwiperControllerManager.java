package com.reactbolt.sdk;

import android.content.Context;
import android.os.Handler;
import android.text.TextUtils;
import android.util.Log;

import com.bolt.consumersdk.CCConsumer;
import com.bolt.consumersdk.domain.CCConsumerAccount;
import com.bolt.consumersdk.domain.CCConsumerError;
import com.bolt.consumersdk.swiper.CCSwiperControllerFactory;
import com.bolt.consumersdk.swiper.SwiperController;
import com.bolt.consumersdk.swiper.SwiperControllerListener;
import com.bolt.consumersdk.swiper.enums.BatteryState;
import com.bolt.consumersdk.swiper.enums.SwiperCaptureMode;
import com.bolt.consumersdk.swiper.enums.SwiperError;
import com.bolt.consumersdk.swiper.enums.SwiperType;

public class SwiperControllerManager {
    public static String TAG = SwiperControllerManager.class.getSimpleName();
    private static final SwiperControllerManager mInstance = new SwiperControllerManager();
    private String mDeviceMACAddress = null;
    private SwiperController mSwiperController;
    private SwiperControllerListener mSwiperControllerListener = null;
    private SwiperCaptureMode mSwiperCaptureMode = SwiperCaptureMode.SWIPE_TAP_INSERT;
    private SwiperType mSwiperType = SwiperType.IDTech;
    private Context mContext = null;
    private boolean bConnected = false;

    public static SwiperControllerManager getInstance() {
        return mInstance;
    }

    private SwiperControllerManager() {
    }

    public void setContext(Context context) {
        mContext = context;
    }

    /***
     * Set bluetooth MAC Address of IDTECH Device
     * @param strMAC
     */
    public void setMACAddress(String strMAC) {
        boolean bReset = false;

        if (strMAC == null || !strMAC.equals(mDeviceMACAddress)) {
            bReset = true;
        }

        mDeviceMACAddress = strMAC;
    }

    public String getMACAddr() {
        return mDeviceMACAddress;
    }

    /***
     *
     * @param swiperCaptureMode
     */
    public void setSwiperCaptureMode(SwiperCaptureMode swiperCaptureMode) {
        mSwiperCaptureMode = swiperCaptureMode;
    }

    /***
     *
     * @return
     */
    public SwiperCaptureMode getSwiperCaptureMode() {
        return mSwiperCaptureMode;
    }

    /***
     *
     */
    public void connectToDevice() {
        if (mSwiperType == SwiperType.IDTech && TextUtils.isEmpty(mDeviceMACAddress)) {
            Log.d(TAG, "Connect to device: mac address empty");
            return;
        }

        if (mContext == null || mDeviceMACAddress == null) {
            Log.d(TAG, "Connect to device: mac address empty");
            return;
        }

        if (mSwiperController != null) {
            disconnectFromDevice();

            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    createSwiperController();
                }
            }, 5000);
        } else {
            createSwiperController();
        }
    }

    /***
     * Create a swiper controller based on the defined swiper type
     */
    private void createSwiperController() {
        SwiperController swiperController = null;

        swiperController = new CCSwiperControllerFactory().create(mContext, mSwiperType, new SwiperControllerListener() {
            @Override
            public void onTokenGenerated(CCConsumerAccount account, CCConsumerError error) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onTokenGenerated(account, error);
                }
            }

            @Override
            public void onError(SwiperError swipeError) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onError(swipeError);
                }
            }

            @Override
            public void onSwiperReadyForCard() {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onSwiperReadyForCard();
                }
            }

            @Override
            public void onSwiperConnected() {
                bConnected = true;
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onSwiperConnected();
                }
            }

            @Override
            public void onSwiperDisconnected() {
                bConnected = false;
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onSwiperDisconnected();
                }
            }

            @Override
            public void onBatteryState(BatteryState batteryState) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onBatteryState(batteryState);
                }
            }

            @Override
            public void onStartTokenGeneration() {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onStartTokenGeneration();
                }
            }

            @Override
            public void onLogUpdate(String strLogUpdate) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onLogUpdate(strLogUpdate);
                }
            }

            @Override
            public void onDeviceConfigurationUpdate(String s) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onDeviceConfigurationUpdate(s);
                }
            }

            @Override
            public void onConfigurationProgressUpdate(double v) {

            }

            @Override
            public void onConfigurationComplete(boolean b) {

            }

            @Override
            public void onTimeout() {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onTimeout();
                }
            }

            @Override
            public void onLCDDisplayUpdate(String str) {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onLogUpdate(str);
                }
            }

            @Override
            public void onRemoveCardRequested() {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onRemoveCardRequested();
                }
            }

            @Override
            public void onCardRemoved() {
                if (mSwiperControllerListener != null) {
                    mSwiperControllerListener.onCardRemoved();
                }
            }

            @Override
            public void onDeviceBusy() {

            }
        }, mDeviceMACAddress, false);

        if (swiperController == null) {
            //Connection to device failed.  Device may be busy, wait and try again.
            Handler handler = new Handler();
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    createSwiperController();
                }
            }, 5000);
        } else {
            mSwiperController = swiperController;
        }

        return;
    }

    /***
     * Disconnect from swiper device
     */
    public void disconnectFromDevice() {
        mSwiperController.release();
        mSwiperController = null;
    }

    /***
     *
     * @param swiperControllerListener
     */
    public void setSwiperControllerListener(SwiperControllerListener swiperControllerListener) {
        mSwiperControllerListener = swiperControllerListener;
    }

    /***
     *
     * @return true if swiper is connected.
     */
    public boolean isSwiperConnected() {
        return bConnected;
    }

    /***
     *
     * @return SwiperController Object
     */
    public SwiperController getSwiperController() {
        return mSwiperController;
    }

    /***
     *
     * @return the type of swiper supported by the current controller
     */
    public SwiperType getSwiperType() {
        return mSwiperType;
    }

    /***
     * Used to set define the type of swiper to create a controller for.  ID_TECH VP3300 or BBPOS
     * @param swiperType
     */
    public void setSwiperType(SwiperType swiperType) {
        boolean bReset = false;

        if (mSwiperType != swiperType) {
            bReset = true;
        }

        mSwiperType = swiperType;
        setupConsumerApi();

        if ((bReset || mSwiperController == null) && !TextUtils.isEmpty(mDeviceMACAddress)) {
            createSwiperController();
        }
    }

    /**
     * Initial Configuration for Consumer Api
     */
    private void setupConsumerApi() {
        switch (SwiperControllerManager.getInstance().getSwiperType()) {
            case BBPosDevice:
                CCConsumer.getInstance().getApi().setEndPoint("https://fts-uat.cardconnect.com");
                // CCConsumer.getInstance().getApi().setEndPoint(mContext.getString(R.string.cardconnect_prod_post_url));
                break;
            case IDTech:
                CCConsumer.getInstance().getApi().setEndPoint("https://fts-uat.cardconnect.com");
                // CCConsumer.getInstance().getApi().setEndPoint(mContext.getString(R.string.cardconnect_prod_post_url));
                //CCConsumer.getInstance().getApi().setEndPoint(mContext.getString(R.string.cardconnect_qa_post_url));
                break;
        }
        CCConsumer.getInstance().getApi().setDebugEnabled(true);
    }
}
